import sys
import os
from datetime import date
from dotenv import load_dotenv
from fastapi import HTTPException, status

dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

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


# ── Nuevas funciones para registro en tiempo real ───────────────────────────

def iniciar_entrenamiento_service(id_usuario: int, id_ejercicio: int, id_rutina: int | None) -> dict:
    """
    Crea UNA fila en `entrenamiento` para un ejercicio concreto.
    La app llama esto al empezar a registrar un ejercicio.
    Devuelve id_entrenamiento para usarlo en registrar_serie_service().

    Tablas:  entrenamiento (INSERT)
    FK:      id_usuario → usuario, id_ejercicio → ejercicios, id_rutina → rutina (nullable)
    """
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

        # Validar usuario
        cursor.execute("SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,))
        if not cursor.fetchone():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

        # Validar ejercicio
        cursor.execute("SELECT id_ejercicio FROM ejercicios WHERE id_ejercicio = %s", (id_ejercicio,))
        if not cursor.fetchone():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Ejercicio no encontrado")

        # Validar rutina si se proporcionó
        if id_rutina is not None:
            cursor.execute(
                "SELECT id_rutina FROM rutina WHERE id_rutina = %s AND id_usuario = %s",
                (id_rutina, id_usuario)
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Rutina no encontrada")

        # Insertar fila en entrenamiento
        cursor.execute(
            "INSERT INTO entrenamiento (id_usuario, id_ejercicio, id_rutina) VALUES (%s, %s, %s) RETURNING id_entrenamiento, fecha",
            (id_usuario, id_ejercicio, id_rutina)
        )
        row = cursor.fetchone()
        conn.commit()

        return {
            "id_entrenamiento": row[0],
            "id_usuario": id_usuario,
            "id_ejercicio": id_ejercicio,
            "id_rutina": id_rutina,
            "fecha": row[1].isoformat() if hasattr(row[1], "isoformat") else str(row[1])
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
            detail="Error al iniciar el entrenamiento"
        )
    finally:
        if conn:
            release_connection(conn)


def obtener_ultimo_registro_ejercicio_service(id_usuario: int, id_ejercicio: int) -> dict:
    """
    Obtiene las series de la ÚLTIMA sesión del ejercicio para un usuario.
    Se usa para mostrar el placeholder gris (peso/reps anteriores) en la app.

    Query:
      1. Busca el entrenamiento más reciente por fecha DESC para ese usuario+ejercicio
      2. Carga todas las series de ese entrenamiento ordenadas por id_serie ASC

    Tablas:  entrenamiento (SELECT) + series (SELECT)
    """
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

        # 1. Entrenamiento más reciente de ese ejercicio
        cursor.execute("""
            SELECT e.id_entrenamiento, e.fecha
            FROM entrenamiento e
            WHERE e.id_usuario = %s AND e.id_ejercicio = %s
            ORDER BY e.fecha DESC
            LIMIT 1
        """, (id_usuario, id_ejercicio))

        row = cursor.fetchone()
        if not row:
            return {"series_anteriores": [], "fecha_sesion": None}

        id_entrenamiento_previo = row[0]
        fecha_sesion = row[1].isoformat() if hasattr(row[1], "isoformat") else str(row[1])

        # 2. Series de esa sesión en orden — excluir drop sets y calentamientos
        cursor.execute("""
            SELECT peso, reps
            FROM series
            WHERE id_entrenamiento = %s AND (tipo_serie IS NULL OR tipo_serie = 'normal')
            ORDER BY id_serie ASC
        """, (id_entrenamiento_previo,))

        series = cursor.fetchall()
        return {
            "series_anteriores": [
                {"numero": i + 1, "peso": float(s[0]), "reps": s[1]}
                for i, s in enumerate(series)
            ],
            "fecha_sesion": fecha_sesion
        }

    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al obtener el último registro del ejercicio"
        )
    finally:
        if conn:
            release_connection(conn)


def registrar_serie_service(
    id_entrenamiento: int, 
    peso: float, 
    reps: int, 
    tipo_serie: str = 'normal',
    id_serie_padre: int | None = None,
) -> dict:
    """
    Inserta UNA sola serie en la tabla `series` inmediatamente al presionar Check ✓.
    Registro en tiempo real — no espera a que termine el entreno.

    Tablas:  series (INSERT)
    FK:      id_entrenamiento → entrenamiento, id_serie_padre → series (nullable)
    Campos:  peso, reps, tipo_serie ('normal'|'calentamiento'|'drop_set'), id_serie_padre
    """
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

        # Validar que el entrenamiento existe
        cursor.execute(
            "SELECT id_entrenamiento FROM entrenamiento WHERE id_entrenamiento = %s",
            (id_entrenamiento,)
        )
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Entrenamiento {id_entrenamiento} no encontrado"
            )

        # Validar que la serie padre existe (si se proporciona)
        if id_serie_padre is not None:
            cursor.execute(
                "SELECT id_serie FROM series WHERE id_serie = %s",
                (id_serie_padre,)
            )
            if not cursor.fetchone():
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Serie padre {id_serie_padre} no encontrada"
                )

        # Validar tipo_serie
        tipos_validos = {'normal', 'calentamiento', 'drop_set'}
        if tipo_serie not in tipos_validos:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"tipo_serie debe ser uno de: {', '.join(tipos_validos)}"
            )

        # Insertar la serie
        cursor.execute(
            """
            INSERT INTO series (id_entrenamiento, peso, reps, tipo_serie, id_serie_padre)
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id_serie
            """,
            (id_entrenamiento, peso, reps, tipo_serie, id_serie_padre)
        )
        id_serie = cursor.fetchone()[0]
        conn.commit()

        return {
            "id_serie": id_serie,
            "id_entrenamiento": id_entrenamiento,
            "peso": peso,
            "reps": reps,
            "tipo_serie": tipo_serie,
            "id_serie_padre": id_serie_padre,
        }

    except HTTPException:
        if conn:
            conn.rollback()
        raise
    except Exception:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error al registrar la serie"
        )
    finally:
        if conn:
            release_connection(conn)
