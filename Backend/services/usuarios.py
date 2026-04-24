import sys
import os
from datetime import datetime
from dotenv import load_dotenv
from fastapi import HTTPException, status

load_dotenv()

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def crear_usuario_service(name: str, surname: str, email: str, peso: float, altura: float) -> dict:
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
        cursor.execute("SELECT id_usuario FROM usuario WHERE email = %s", (email,))
        if cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El email ya está registrado"
            )

        cursor.execute(
            """
            INSERT INTO usuario (name, surname, email, peso, altura, fecha_creacion)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id_usuario, fecha_creacion
            """,
            (name, surname, email, peso, altura, datetime.now())
        )

        resultado = cursor.fetchone()
        conn.commit()

        return {
            "id_usuario": resultado[0],
            "name": name,
            "surname": surname,
            "email": email,
            "peso": peso,
            "altura": altura,
            "fecha_creacion": resultado[1].isoformat()
        }

    except HTTPException:
        raise
    except Exception:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear el usuario en la base de datos"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_usuario_service(id_usuario: int) -> dict:
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
            "SELECT id_usuario, name, surname, email, peso, altura, fecha_creacion "
            "FROM usuario WHERE id_usuario = %s",
            (id_usuario,)
        )
        usuario = cursor.fetchone()
        if not usuario:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )

        return {
            "id_usuario": usuario[0],
            "name": usuario[1],
            "surname": usuario[2],
            "email": usuario[3],
            "peso": usuario[4],
            "altura": usuario[5],
            "fecha_creacion": usuario[6].isoformat()
        }

    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener el usuario"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_progreso_usuario_service(id_usuario: int) -> list[dict]:
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
            "SELECT peso, date, objetivo FROM progreso_usuario "
            "WHERE id_usuario = %s ORDER BY date DESC",
            (id_usuario,)
        )
        filas = cursor.fetchall()

        return [
            {
                "peso": fila[0],
                "date": fila[1].isoformat() if hasattr(fila[1], "isoformat") else str(fila[1]),
                "objetivo": fila[2]
            }
            for fila in filas
        ]

    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener el progreso del usuario"
        )
    finally:
        if conn:
            release_connection(conn)
