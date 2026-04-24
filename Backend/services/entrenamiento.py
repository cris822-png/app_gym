import sys
import os
from datetime import date
from dotenv import load_dotenv
from fastapi import HTTPException, status

load_dotenv()

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def registrar_entrenamiento_service(id_usuario: int, id_rutina: int, fecha: date, ejercicios: list[dict]) -> dict:
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

        cursor.execute("SELECT id_rutina FROM rutina WHERE id_rutina = %s AND id_usuario = %s", (id_rutina, id_usuario))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="La rutina no existe o no pertenece al usuario"
            )

        entrenos_guardados = []
        for ejercicio in ejercicios:
            id_ejercicio = ejercicio.get("id_ejercicio")
            series = ejercicio.get("series")
            if not id_ejercicio or not series:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cada ejercicio debe incluir id_ejercicio y al menos una serie"
                )

            cursor.execute("SELECT id_ejercicio FROM ejercicios WHERE id_ejercicio = %s", (id_ejercicio,))
            if not cursor.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"El ejercicio {id_ejercicio} no existe"
                )

            cursor.execute(
                "INSERT INTO entrenamiento (id_usuario, id_rutina, id_ejercicio, fecha) VALUES (%s, %s, %s, %s) RETURNING id_entrenamiento",
                (id_usuario, id_rutina, id_ejercicio, fecha)
            )
            id_entrenamiento = cursor.fetchone()[0]

            for serie in series:
                peso = serie.get("peso")
                reps = serie.get("reps")
                if peso is None or reps is None or reps <= 0 or peso <= 0:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Cada serie debe tener peso y reps válidos"
                    )

                cursor.execute(
                    "INSERT INTO series (id_entrenamiento, peso, reps) VALUES (%s, %s, %s)",
                    (id_entrenamiento, peso, reps)
                )

            entrenos_guardados.append({
                "id_entrenamiento": id_entrenamiento,
                "id_ejercicio": id_ejercicio,
                "series": series
            })

        conn.commit()
        return {
            "id_usuario": id_usuario,
            "id_rutina": id_rutina,
            "fecha": fecha.isoformat(),
            "entrenamientos": entrenos_guardados
        }

    except HTTPException:
        if conn:
            conn.rollback()
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al registrar el entrenamiento"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_entrenamientos_usuario_service(id_usuario: int) -> list[dict]:
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
            "SELECT e.id_entrenamiento, e.id_ejercicio, ex.name, e.fecha "
            "FROM entrenamiento e "
            "JOIN ejercicios ex ON ex.id_ejercicio = e.id_ejercicio "
            "WHERE e.id_usuario = %s ORDER BY e.fecha DESC, e.id_entrenamiento DESC",
            (id_usuario,)
        )
        filas = cursor.fetchall()

        entrenamientos = []
        for fila in filas:
            id_entrenamiento = fila[0]
            cursor.execute("SELECT peso, reps FROM series WHERE id_entrenamiento = %s ORDER BY id_serie", (id_entrenamiento,))
            series = cursor.fetchall()
            entrenamientos.append({
                "id_entrenamiento": id_entrenamiento,
                "id_ejercicio": fila[1],
                "nombre_ejercicio": fila[2],
                "fecha": fila[3].isoformat() if hasattr(fila[3], "isoformat") else str(fila[3]),
                "series": [{"peso": s[0], "reps": s[1]} for s in series]
            })

        return entrenamientos

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener los entrenamientos"
        )
    finally:
        if conn:
            release_connection(conn)
