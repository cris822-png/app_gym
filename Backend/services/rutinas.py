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
    Crea rutina + rutina_ejercicio + entrenamiento + series en una única transacción.

    Jerarquía de tablas respetada:
      rutina  →  rutina_ejercicio  (plantilla de ejercicios de la rutina)
      entrenamiento  →  series     (registros reales de series, ligados al usuario)

    El id_entrenamiento que se usa en series.id_entrenamiento proviene de la
    tabla `entrenamiento`, no de `rutina_ejercicio`. Esto es lo que exige la FK
    `series_id_entrenamiento_fkey`.
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

        # ── 1. Verificar que el usuario existe ──────────────────────────────
        cursor.execute("SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,))
        if not cursor.fetchone():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="El usuario no existe")

        if not name_rutina or len(name_rutina.strip()) == 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="El nombre de la rutina no puede estar vacío")

        # ── 2. Insertar cabecera de rutina ──────────────────────────────────
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
            series_payload = ejercicio_obj.get("series")
            orden = ejercicio_obj.get("orden") or idx

            if not id_ejercicio or not series_payload:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cada ejercicio debe incluir 'id_ejercicio' y al menos una 'series'"
                )

            # ── 3. Verificar que el ejercicio existe ────────────────────────
            cursor.execute("SELECT id_ejercicio FROM ejercicios WHERE id_ejercicio = %s", (id_ejercicio,))
            if not cursor.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"El ejercicio {id_ejercicio} no existe"
                )

            # ── 4. Insertar en rutina_ejercicio (plantilla) ─────────────────
            cursor.execute(
                """
                INSERT INTO rutina_ejercicio (id_rutina, id_ejercicio, orden)
                VALUES (%s, %s, %s)
                RETURNING id_rutina_ejercicio
                """,
                (id_rutina, id_ejercicio, orden)
            )
            id_rutina_ejercicio = cursor.fetchone()[0]

            # ── 5. Insertar en entrenamiento (registro real) ────────────────
            #    La tabla `series` tiene FK → entrenamiento.id_entrenamiento,
            #    por lo que necesitamos un registro válido en `entrenamiento`
            #    antes de poder insertar series.
            cursor.execute(
                """
                INSERT INTO entrenamiento (id_usuario, id_ejercicio, fecha)
                VALUES (%s, %s, %s)
                RETURNING id_entrenamiento
                """,
                (id_usuario, id_ejercicio, fecha)
            )
            id_entrenamiento = cursor.fetchone()[0]

            # ── 6. Insertar series (usando id_entrenamiento real) ───────────
            created_series = []
            for serie in series_payload:
                reps = serie.get("reps")
                peso = serie.get("peso")
                # tiempo_descanso en la BD es INTEGER (segundos)
                tiempo_descanso_raw = serie.get("tiempo_descanso")
                if isinstance(tiempo_descanso_raw, str):
                    # Convertir "60s" → 60 ó "01:00" → 60; si no parseable, None
                    import re
                    m = re.match(r'^(\d+)', tiempo_descanso_raw)
                    tiempo_descanso = int(m.group(1)) if m else None
                else:
                    tiempo_descanso = int(tiempo_descanso_raw) if tiempo_descanso_raw is not None else None

                if reps is None:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Cada serie necesita 'reps'"
                    )

                cursor.execute(
                    """
                    INSERT INTO series (id_entrenamiento, peso, reps, tiempo_descanso)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id_serie
                    """,
                    (id_entrenamiento, peso, reps, tiempo_descanso)
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
                "id_entrenamiento": id_entrenamiento,
                "id_ejercicio": id_ejercicio,
                "orden": orden,
                "series": created_series
            })

        # ── 7. Commit de la transacción completa ────────────────────────────
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
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear la rutina completa: {str(e)}"
        )
    finally:
        if conn:
            release_connection(conn)

