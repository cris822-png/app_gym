import sys
import os
import hashlib
import hmac
import secrets
from datetime import datetime
from dotenv import load_dotenv
from fastapi import HTTPException, status

# Cargar variables de entorno desde el .env raíz aunque el app se inicie desde Backend/
dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def _usuario_tiene_columna(cursor, column_name: str) -> bool:
    cursor.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_name = 'usuario' AND column_name = %s",
        (column_name,)
    )
    return cursor.fetchone() is not None


def _usuario_tiene_columna_peso(cursor) -> bool:
    return _usuario_tiene_columna(cursor, 'peso')


def _usuario_tiene_columnas_objetivo(cursor) -> bool:
    return (_usuario_tiene_columna(cursor, 'objetivo_porcentage') and
            _usuario_tiene_columna(cursor, 'objetivo_peso'))


def _hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    hashed = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000)
    return f"{salt}${hashed.hex()}"


def _is_hashed_password(stored_password: str) -> bool:
    if '$' not in stored_password:
        return False
    parts = stored_password.split('$', 1)
    return len(parts) == 2 and all(parts)


def _hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    hashed = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000)
    return f"{salt}${hashed.hex()}"


def _verify_password(password: str, stored_password: str) -> bool:
    if not _is_hashed_password(stored_password):
        return password == stored_password

    salt, expected_hash = stored_password.split('$', 1)
    hashed = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt.encode('utf-8'), 100000).hex()
    return hmac.compare_digest(hashed, expected_hash)


def crear_usuario_service(name: str, surname: str, email: str, password: str, peso: float, altura: float, objetivo_porcentage: str | None = None, objetivo_peso: str | None = None) -> dict:
    hashed_password = _hash_password(password)
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
            if _usuario_tiene_columnas_objetivo(cursor):
                cursor.execute(
                    """
                    INSERT INTO usuario (name, surname, email, password, peso, altura, objetivo_porcentage, objetivo_peso, fecha_creacion)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id_usuario, fecha_creacion
                    """,
                    (name, surname, email, hashed_password, peso, altura, objetivo_porcentage, objetivo_peso, datetime.now())
                )
            else:
                cursor.execute(
                    """
                    INSERT INTO usuario (name, surname, email, password, peso, altura, fecha_creacion)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                    RETURNING id_usuario, fecha_creacion
                    """,
                    (name, surname, email, hashed_password, peso, altura, datetime.now())
                )
        else:
            cursor.execute(
                """
                INSERT INTO usuario (name, surname, email, password, altura, fecha_creacion)
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING id_usuario, fecha_creacion
                """,
                (name, surname, email, hashed_password, altura, datetime.now())
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
            if _usuario_tiene_columnas_objetivo(cursor):
                cursor.execute(
                    "SELECT id_usuario, name, surname, email, peso, altura, objetivo_porcentage, objetivo_peso, fecha_creacion "
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
                objetivo_porcentage = usuario[6]
                objetivo_peso = usuario[7]
                fecha_valor = usuario[8]
            else:
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
                objetivo_porcentage = None
                objetivo_peso = None
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
            objetivo_porcentage = None
            objetivo_peso = None
            fecha_valor = usuario[5]

        return {
            "id_usuario": usuario[0],
            "name": usuario[1],
            "surname": usuario[2],
            "email": usuario[3],
            "peso": peso_valor,
            "altura": altura_valor,
            "objetivo_porcentage": objetivo_porcentage,
            "objetivo_peso": objetivo_peso,
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


def actualizar_usuario_service(id_usuario: int, objetivo_porcentage: str | None = None, objetivo_peso: str | None = None) -> dict:
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
        if cursor.fetchone() is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )

        if not _usuario_tiene_columnas_objetivo(cursor):
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Las columnas de objetivo no existen en la base de datos"
            )

        updates = []
        params = []
        if objetivo_porcentage is not None:
            updates.append("objetivo_porcentage = %s")
            params.append(objetivo_porcentage.strip())
        if objetivo_peso is not None:
            updates.append("objetivo_peso = %s")
            params.append(objetivo_peso.strip())

        if updates:
            cursor.execute(
                f"UPDATE usuario SET {', '.join(updates)} WHERE id_usuario = %s RETURNING id_usuario, name, surname, email, peso, altura, objetivo_porcentage, objetivo_peso, fecha_creacion",
                (*params, id_usuario)
            )
            usuario = cursor.fetchone()
            conn.commit()
        else:
            cursor.execute(
                "SELECT id_usuario, name, surname, email, peso, altura, objetivo_porcentage, objetivo_peso, fecha_creacion "
                "FROM usuario WHERE id_usuario = %s",
                (id_usuario,)
            )
            usuario = cursor.fetchone()

        return {
            "id_usuario": usuario[0],
            "name": usuario[1],
            "surname": usuario[2],
            "email": usuario[3],
            "peso": usuario[4],
            "altura": usuario[5],
            "objetivo_porcentage": usuario[6],
            "objetivo_peso": usuario[7],
            "fecha_creacion": usuario[8].isoformat()
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


def login_usuario_service(email: str, password: str) -> dict:
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
            if _usuario_tiene_columnas_objetivo(cursor):
                cursor.execute(
                    "SELECT id_usuario, name, surname, email, password, peso, altura, objetivo_porcentage, objetivo_peso, fecha_creacion "
                    "FROM usuario WHERE email = %s",
                    (email,)
                )
                usuario = cursor.fetchone()
                if not usuario or not _verify_password(password, usuario[4]):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Correo o contraseña incorrectos"
                    )

                if not _is_hashed_password(usuario[4]):
                    cursor.execute(
                        "UPDATE usuario SET password = %s WHERE id_usuario = %s",
                        (_hash_password(password), usuario[0])
                    )
                    conn.commit()

                peso_valor = usuario[5]
                altura_valor = usuario[6]
                objetivo_porcentage = usuario[7]
                objetivo_peso = usuario[8]
                fecha_valor = usuario[9]
            else:
                cursor.execute(
                    "SELECT id_usuario, name, surname, email, password, peso, altura, fecha_creacion "
                    "FROM usuario WHERE email = %s",
                    (email,)
                )
                usuario = cursor.fetchone()
                if not usuario or not _verify_password(password, usuario[4]):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Correo o contraseña incorrectos"
                    )

                if not _is_hashed_password(usuario[4]):
                    cursor.execute(
                        "UPDATE usuario SET password = %s WHERE id_usuario = %s",
                        (_hash_password(password), usuario[0])
                    )
                    conn.commit()

                peso_valor = usuario[5]
                altura_valor = usuario[6]
                objetivo_porcentage = None
                objetivo_peso = None
                fecha_valor = usuario[7]
        else:
            cursor.execute(
                "SELECT id_usuario, name, surname, email, password, altura, fecha_creacion "
                "FROM usuario WHERE email = %s",
                (email,)
            )
            usuario = cursor.fetchone()
            if not usuario or not _verify_password(password, usuario[4]):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Correo o contraseña incorrectos"
                )

            if not _is_hashed_password(usuario[4]):
                cursor.execute(
                    "UPDATE usuario SET password = %s WHERE id_usuario = %s",
                    (_hash_password(password), usuario[0])
                )
                conn.commit()

            peso_valor = 0.0
            altura_valor = usuario[5]
            objetivo_porcentage = None
            objetivo_peso = None
            fecha_valor = usuario[6]

        return {
            "id_usuario": usuario[0],
            "name": usuario[1],
            "surname": usuario[2],
            "email": usuario[3],
            "peso": peso_valor,
            "altura": altura_valor,
            "objetivo_porcentage": objetivo_porcentage,
            "objetivo_peso": objetivo_peso,
            "fecha_creacion": fecha_valor.isoformat()
        }

    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al autenticar el usuario"
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
            "SELECT peso, fecha FROM progreso_usuario "
            "WHERE id_usuario = %s ORDER BY fecha DESC",
            (id_usuario,)
        )
        filas = cursor.fetchall()

        return [
            {
                "peso": fila[0],
                "date": fila[1].isoformat() if hasattr(fila[1], "isoformat") else str(fila[1]),
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


def registrar_progreso_usuario_service(id_usuario: int, peso: float) -> dict:
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
        if cursor.fetchone() is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Usuario no encontrado"
            )

        cursor.execute(
            "INSERT INTO progreso_usuario (id_usuario, peso, fecha) VALUES (%s, %s, %s) RETURNING peso, fecha",
            (id_usuario, peso, datetime.now().date())
        )
        fila = cursor.fetchone()
        conn.commit()

        return {
            "peso": fila[0],
            "date": fila[1].isoformat() if hasattr(fila[1], "isoformat") else str(fila[1]),
        }

    except HTTPException:
        raise
    except Exception:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al registrar el progreso del usuario"
        )
    finally:
        if conn:
            release_connection(conn)
