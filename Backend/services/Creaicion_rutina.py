import sys
import os
from datetime import datetime, date
from dotenv import load_dotenv
from fastapi import HTTPException, status

load_dotenv()

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def crear_rutina_service(id_usuario: int, name_rutina: str, fecha: date) -> dict:
    """
    Servicio para crear una nueva rutina en la base de datos.
    
    Args:
        id_usuario: ID del usuario propietario de la rutina
        name_rutina: Nombre de la rutina
        fecha: Fecha de creación de la rutina
        
    Returns:
        dict: Con datos de la rutina creada
        
    Raises:
        HTTPException: Si hay error en la validación o en la BD
    """
    
    conn = None
    try:
        # Conectar a la base de datos
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
        
        # Verificar que el usuario existe
        cursor.execute("SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El usuario no existe"
            )
        
        # Validar que el nombre de la rutina no esté vacío
        if not name_rutina or len(name_rutina.strip()) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El nombre de la rutina no puede estar vacío"
            )
        
        # Insertar la nueva rutina
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
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear la rutina en la base de datos"
        )
    
    finally:
        if conn:
            release_connection(conn)
