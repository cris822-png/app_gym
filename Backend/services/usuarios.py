import sys
import os
from datetime import datetime
from dotenv import load_dotenv
from fastapi import HTTPException, status

load_dotenv()

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def _usuario_tiene_columna_peso(cursor) -> bool:
    cursor.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_name = 'usuario' AND column_name = 'peso'"
    )
    return cursor.fetchone() is not None


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

        if _usuario_tiene_columna_peso(cursor):
            cursor.execute(
                """
                INSERT INTO usuario (name, surname, email, peso, altura, fecha_creacion)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id_usuario, fecha_creacion
                """,
                (name, surname, email, peso, altura, datetime.now())
            )
        else:
            cursor.execute(
                """
                INSERT INTO usuario (name, surname, email, altura, fecha_creacion)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING id_usuario, fecha_creacion
                """,
                (name, surname, email, altura, datetime.now())
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
        if _usuario_tiene_columna_peso(cursor):
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
            peso_valor = usuario[4]
            altura_valor = usuario[5]
            fecha_valor = usuario[6]
        else:
            cursor.execute(
                "SELECT id_usuario, name, surname, email, altura, fecha_creacion "
                "FROM usuario WHERE id_usuario = %s",
                (id_usuario,)
            )
            usuario = cursor.fetchone()
            if not usuario:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Usuario no encontrado"
                )
            peso_valor = 0.0
            altura_valor = usuario[4]
            fecha_valor = usuario[5]

        return {
            "id_usuario": usuario[0],
            "name": usuario[1],
            "surname": usuario[2],
            "email": usuario[3],
            "peso": peso_valor,
            "altura": altura_valor,
            "fecha_creacion": fecha_valor.isoformat()
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
            "SELECT peso, fecha, objetivo FROM progreso_usuario "
            "WHERE id_usuario = %s ORDER BY fecha DESC",
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
