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
    """
    Servicio para crear un nuevo usuario en la base de datos.
    
    Args:
        name: Nombre del usuario
        surname: Apellido del usuario
        email: Email del usuario (debe ser único)
        peso: Peso en kg
        altura: Altura en cm
        
    Returns:
        dict: Con datos del usuario creado
        
    Raises:
        HTTPException: Si hay error en la conexión, email duplicado o error en BD
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
        
        # Verificar si el email ya existe
        cursor.execute("SELECT id_usuario FROM usuario WHERE email = %s", (email,))
        if cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="El email ya está registrado"
            )
        
        # Insertar el nuevo usuario
        cursor.execute(
            """
            INSERT INTO usuario (name, surname, email, peso, altura, fecha_creacion)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id_usuario
            """,
            (name, surname, email, peso, altura, datetime.now())
        )
        
        id_usuario = cursor.fetchone()[0]
        conn.commit()
        
        return {
            "id_usuario": id_usuario,
            "name": name,
            "surname": surname,
            "email": email,
            "peso": peso,
            "altura": altura
        }
        
    except HTTPException:
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al crear el usuario en la base de datos"
        )
    
    finally:
        if conn:
            release_connection(conn)
