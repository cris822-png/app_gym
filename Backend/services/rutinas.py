import sys
import os
from dotenv import load_dotenv
from datetime import date
from fastapi import HTTPException, status

dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def crear_rutina_service(id_usuario: int, name_rutina: str, fecha: date) -> dict:
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )

        if not conn:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="No se pudo conectar a la base de datos"
            )

        cursor = conn.cursor()
        cursor.execute("SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El usuario no existe"
            )

        if not name_rutina or len(name_rutina.strip()) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El nombre de la rutina no puede estar vacío"
            )

        cursor.execute(
            """
            INSERT INTO rutina (id_usuario, name_rutina, fecha)
            VALUES (%s, %s, %s)
            RETURNING id_rutina
            """,
            (id_usuario, name_rutina.strip(), fecha)
        )

        id_rutina = cursor.fetchone()[0]
        conn.commit()

        return {
            "id_rutina": id_rutina,
            "id_usuario": id_usuario,
            "name_rutina": name_rutina.strip(),
            "fecha": fecha.isoformat()
        }

    except HTTPException:
        raise
    except Exception:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear la rutina en la base de datos"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_rutinas_usuario_service(id_usuario: int) -> list[dict]:
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )

        if not conn:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="No se pudo conectar a la base de datos"
            )

        cursor = conn.cursor()
        cursor.execute(
            "SELECT id_rutina, id_usuario, name_rutina, fecha FROM rutina "
            "WHERE id_usuario = %s ORDER BY fecha DESC",
            (id_usuario,)
        )
        filas = cursor.fetchall()

        return [
            {
                "id_rutina": fila[0],
                "id_usuario": fila[1],
                "name_rutina": fila[2],
                "fecha": fila[3].isoformat() if hasattr(fila[3], "isoformat") else str(fila[3])
            }
            for fila in filas
        ]

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener las rutinas del usuario"
        )
    finally:
        if conn:
            release_connection(conn)


def crear_rutina_completa_service(id_usuario: int, name_rutina: str, fecha: date, ejercicios: list[dict]) -> dict:
    """
    Crea rutina + rutina_ejercicio + series en una única transacción.
    Se asume que `series.id_entrenamiento` usará el id generado en `rutina_ejercicio`.
    """
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            port=os.getenv("DB_PORT", "5432")
        )
        if not conn:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="No se pudo conectar a la base de datos"
            )

        cursor = conn.cursor()

        # Verificar usuario
        cursor.execute("SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,))
        if not cursor.fetchone():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El usuario no existe")

        if not name_rutina or len(name_rutina.strip()) == 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El nombre de la rutina no puede estar vacío")

        # Insertar rutina
        cursor.execute(
            """
            INSERT INTO rutina (id_usuario, name_rutina, fecha)
            VALUES (%s, %s, %s)
            RETURNING id_rutina
            """,
            (id_usuario, name_rutina.strip(), fecha)
        )
        row = cursor.fetchone()
        if not row:
            raise Exception("No se pudo crear la rutina")
        id_rutina = row[0]

        created_ejercicios = []
        for idx, ejercicio_obj in enumerate(ejercicios, start=1):
            id_ejercicio = ejercicio_obj.get("id_ejercicio")
            series = ejercicio_obj.get("series")
            orden = ejercicio_obj.get("orden") or idx

            if not id_ejercicio or not series:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cada ejercicio debe incluir 'id_ejercicio' y al menos una 'series'"
                )

            # Verificar existencia del ejercicio
            cursor.execute("SELECT id_ejercicio FROM ejercicios WHERE id_ejercicio = %s", (id_ejercicio,))
            if not cursor.fetchone():
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"El ejercicio {id_ejercicio} no existe")

            # Insertar rutina_ejercicio
            cursor.execute(
                """
                INSERT INTO rutina_ejercicio (id_rutina, id_ejercicio, orden)
                VALUES (%s, %s, %s)
                RETURNING id_rutina_ejercicio
                """,
                (id_rutina, id_ejercicio, orden)
            )
            id_rutina_ejercicio = cursor.fetchone()[0]

            created_series = []
            for serie in series:
                reps = serie.get("reps")
                peso = serie.get("peso")
                tiempo_descanso = serie.get("tiempo_descanso")

                if reps is None:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cada serie necesita 'reps'")

                cursor.execute(
                    """
                    INSERT INTO series (id_entrenamiento, peso, reps, tiempo_descanso)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id_serie
                    """,
                    (id_rutina_ejercicio, peso, reps, tiempo_descanso)
                )
                id_serie = cursor.fetchone()[0]
                created_series.append({
                    "id_serie": id_serie,
                    "reps": reps,
                    "peso": peso,
                    "tiempo_descanso": tiempo_descanso
                })

            created_ejercicios.append({
                "id_rutina_ejercicio": id_rutina_ejercicio,
                "id_ejercicio": id_ejercicio,
                "orden": orden,
                "series": created_series
            })

        conn.commit()

        return {
            "id_rutina": id_rutina,
            "id_usuario": id_usuario,
            "name_rutina": name_rutina.strip(),
            "fecha": fecha.isoformat(),
            "ejercicios": created_ejercicios
        }

    except HTTPException:
        if conn:
            conn.rollback()
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Error al crear la rutina completa: {str(e)}")
    finally:
        if conn:
            release_connection(conn)
