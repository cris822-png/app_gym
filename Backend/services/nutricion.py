import sys
import os
from dotenv import load_dotenv
from fastapi import HTTPException, status

load_dotenv()

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def crear_nutricion_service(id_usuario: int, comida: str, time: str) -> dict:
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

        cursor.execute(
            """
            INSERT INTO nutricion (id_usuario, comida, time)
            VALUES (%s, %s, %s)
            RETURNING id_nutricion
            """,
            (id_usuario, comida.strip(), time)
        )

        id_nutricion = cursor.fetchone()[0]
        conn.commit()

        return {
            "id_nutricion": id_nutricion,
            "id_usuario": id_usuario,
            "comida": comida.strip(),
            "time": time
        }

    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al registrar la nutrición del usuario"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_nutricion_usuario_service(id_usuario: int) -> list[dict]:
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
        cursor.execute("SELECT id_nutricion, comida, time FROM nutricion WHERE id_usuario = %s ORDER BY time DESC", (id_usuario,))
        filas = cursor.fetchall()

        return [
            {
                "id_nutricion": fila[0],
                "id_usuario": id_usuario,
                "comida": fila[1],
                "time": fila[2].isoformat() if hasattr(fila[2], "isoformat") else str(fila[2])
            }
            for fila in filas
        ]

    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener los datos de nutrición"
        )
    finally:
        if conn:
            release_connection(conn)
