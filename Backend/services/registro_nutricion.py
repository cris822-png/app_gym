import sys
import os
import logging
from datetime import datetime, date
from dotenv import load_dotenv
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)


dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


# ────────────────────────────────────────────────────────────────────────────
# ESCRITURA — solo endpoints de usuario, nunca desde la IA
# ────────────────────────────────────────────────────────────────────────────

def registrar_registro_nutricion_service(
    id_usuario: int,
    comida: str,
    cantidad_g: float,
    tipo_comida: str,
    fecha_consumo: datetime,
    detalles: str | None = None,
) -> dict:
    """
    INSERT en registro_nutricion (incluye campo opcional 'detalles').

    Tablas: registro_nutricion (INSERT)
    La IA tiene PROHIBIDO llamar a este servicio.
    """
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
        )
        if not conn:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="No se pudo conectar a la base de datos",
            )

        cursor = conn.cursor()

        # Verificar usuario
        cursor.execute("SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El usuario no existe",
            )

        cursor.execute(
            """
            INSERT INTO registro_nutricion
                (id_usuario, comida, cantidad_g, tipo_comida, fecha_consumo, detalles)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id_registro
            """,
            (
                id_usuario,
                comida.strip(),
                cantidad_g,
                tipo_comida.strip().lower(),
                fecha_consumo,
                detalles.strip() if detalles and detalles.strip() else None,
            ),
        )
        id_registro = cursor.fetchone()[0]
        conn.commit()

        return {
            "id_registro": id_registro,
            "id_usuario": id_usuario,
            "comida": comida.strip(),
            "cantidad_g": cantidad_g,
            "tipo_comida": tipo_comida.strip().lower(),
            "detalles": detalles,
            "fecha_consumo": fecha_consumo.isoformat(),
        }

    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        logger.error("Error al guardar registro nutricional usuario id=%s: %s", id_usuario, e, exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error interno del servidor",
        )
    finally:
        if conn:
            release_connection(conn)


# ────────────────────────────────────────────────────────────────────────────
# LECTURA — usada por el chatbot para inyectar contexto (solo SELECT)
# ────────────────────────────────────────────────────────────────────────────

def obtener_registros_nutricion_hoy_service(id_usuario: int, fecha: date | None = None) -> list[dict]:
    """
    SELECT en registro_nutricion para el día indicado (defecto: hoy).
    Solo lectura. La IA la llama para construir el context del system prompt.
    Incluye 'detalles' para enriquecer el contexto del LLM.

    Tablas: registro_nutricion (SELECT)
    """
    if fecha is None:
        fecha = date.today()

    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
        )
        if not conn:
            return []

        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT id_registro, comida, cantidad_g, tipo_comida, detalles, fecha_consumo
            FROM registro_nutricion
            WHERE id_usuario = %s
              AND fecha_consumo::date = %s
            ORDER BY fecha_consumo ASC
            """,
            (id_usuario, fecha),
        )
        filas = cursor.fetchall()

        return [
            {
                "id_registro": fila[0],
                "comida": fila[1],
                "cantidad_g": float(fila[2]),
                "tipo_comida": fila[3],
                "detalles": fila[4],
                "fecha_consumo": fila[5].isoformat() if hasattr(fila[5], "isoformat") else str(fila[5]),
            }
            for fila in filas
        ]

    except Exception:
        return []
    finally:
        if conn:
            release_connection(conn)


def obtener_todos_registros_nutricion_service(id_usuario: int) -> list[dict]:
    """
    SELECT de todos los registros nutricionales del usuario.
    Usado para el historial en la pantalla de nutrición.
    """
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
        )
        if not conn:
            return []

        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT id_registro, comida, cantidad_g, tipo_comida, detalles, fecha_consumo
            FROM registro_nutricion
            WHERE id_usuario = %s
            ORDER BY fecha_consumo DESC
            LIMIT 50
            """,
            (id_usuario,),
        )
        filas = cursor.fetchall()

        return [
            {
                "id_registro": fila[0],
                "comida": fila[1],
                "cantidad_g": float(fila[2]),
                "tipo_comida": fila[3],
                "detalles": fila[4],
                "fecha_consumo": fila[5].isoformat() if hasattr(fila[5], "isoformat") else str(fila[5]),
            }
            for fila in filas
        ]

    except Exception:
        return []
    finally:
        if conn:
            release_connection(conn)
