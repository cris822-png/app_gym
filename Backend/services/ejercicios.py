import sys
import os
import logging
from dotenv import load_dotenv
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def crear_ejercicio_service(name: str, musculos_principales: str, musculos_secundarios: str | None, material: str | None, tiempo_descanso: str | None) -> dict:
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
            """
            INSERT INTO ejercicios (name, musculos_principales, musculos_secundarios, material, tiempo_descanso)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id_ejercicio
            """,
            (name.strip(), musculos_principales.strip(), musculos_secundarios, material, tiempo_descanso)
        )

        id_ejercicio = cursor.fetchone()[0]
        conn.commit()

        return {
            "id_ejercicio": id_ejercicio,
            "name": name.strip(),
            "musculos_principales": musculos_principales.strip(),
            "musculos_secundarios": musculos_secundarios,
            "material": material,
            "tiempo_descanso": tiempo_descanso
        }

    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error("Error al crear ejercicio: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear el ejercicio en la base de datos"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_ejercicios_service() -> list[dict]:
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
            "SELECT id_ejercicio, name, musculos_principales, musculos_secundarios, material, descanso_default_seg "
            "FROM ejercicios ORDER BY name"
        )
        filas = cursor.fetchall()

        return [
            {
                "id_ejercicio": fila[0],
                "name": fila[1],
                "musculos_principales": fila[2],
                "musculos_secundarios": fila[3],
                "material": fila[4],
                "descanso_default_seg": fila[5]
            }
            for fila in filas
        ]

    except HTTPException:
        raise
    except Exception as e:
        logger.error("Error al obtener ejercicios: %s", e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener los ejercicios"
        )
    finally:
        if conn:
            release_connection(conn)
