import sys
import os
from dotenv import load_dotenv
from datetime import date
from fastapi import HTTPException, status

dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


# ── Helpers de conexión ──────────────────────────────────────────────────────

def _get_conn():
    conn = connect_bbdd_pgsql(
        host=os.getenv("DB_HOST"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        port=os.getenv("DB_PORT", "5432"),
    )
    if not conn:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No se pudo conectar a la base de datos",
        )
    return conn


# ── Crear rutina completa (Rutina → Días → Ejercicios) ───────────────────────

def crear_rutina_completa_service(
    id_usuario: int,
    name_rutina: str,
    fecha: date,
    dias: list[dict],
) -> dict:
    """
    Crea una rutina con jerarquía de 3 niveles en una única transacción:
      rutina  →  rutina_dia  →  rutina_ejercicio

    La tabla `entrenamiento` NO se toca aquí — es para registros activos,
    no para plantillas de rutina.

    Payload esperado (dias):
      [
        {
          "nombre_dia": "Lunes",
          "ejercicios": [
            {"id_ejercicio": 3, "orden": 1},
            {"id_ejercicio": 5, "orden": 2}
          ]
        },
        ...
      ]
    """
    conn = None
    try:
        conn = _get_conn()
        cursor = conn.cursor()

        # ── 1. Validar usuario ───────────────────────────────────────────────
        cursor.execute(
            "SELECT id_usuario FROM usuario WHERE id_usuario = %s", (id_usuario,)
        )
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El usuario no existe",
            )

        if not name_rutina or not name_rutina.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El nombre de la rutina no puede estar vacío",
            )

        # ── 2. Insertar cabecera de rutina ───────────────────────────────────
        cursor.execute(
            """
            INSERT INTO rutina (id_usuario, name_rutina, fecha)
            VALUES (%s, %s, %s)
            RETURNING id_rutina
            """,
            (id_usuario, name_rutina.strip(), fecha),
        )
        id_rutina = cursor.fetchone()[0]

        # ── 3. Insertar días y ejercicios de cada día ────────────────────────
        created_dias = []
        for dia_obj in dias:
            nombre_dia = dia_obj.get("nombre_dia", "").strip()
            if not nombre_dia:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cada día debe tener un 'nombre_dia' no vacío",
                )

            ejercicios_payload = dia_obj.get("ejercicios", [])
            if not ejercicios_payload:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"El día '{nombre_dia}' debe tener al menos un ejercicio",
                )

            # INSERT en rutina_dia
            cursor.execute(
                """
                INSERT INTO rutina_dia (id_rutina, nombre_dia)
                VALUES (%s, %s)
                RETURNING id_rutina_dia
                """,
                (id_rutina, nombre_dia),
            )
            id_rutina_dia = cursor.fetchone()[0]

            # INSERT de cada ejercicio en rutina_ejercicio
            created_ejercicios = []
            for idx, ej_obj in enumerate(ejercicios_payload, start=1):
                id_ejercicio = ej_obj.get("id_ejercicio")
                orden = ej_obj.get("orden") or idx
                grupo_superset = ej_obj.get("grupo_superset")  # nullable

                if not id_ejercicio:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Cada ejercicio debe tener 'id_ejercicio'",
                    )

                # Verificar que el ejercicio existe
                cursor.execute(
                    "SELECT id_ejercicio, name FROM ejercicios WHERE id_ejercicio = %s",
                    (id_ejercicio,),
                )
                ej_row = cursor.fetchone()
                if not ej_row:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"El ejercicio {id_ejercicio} no existe",
                    )

                cursor.execute(
                    """
                    INSERT INTO rutina_ejercicio (id_rutina_dia, id_ejercicio, orden, grupo_superset)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id_rutina_ejercicio
                    """,
                    (id_rutina_dia, id_ejercicio, orden, grupo_superset),
                )
                id_rutina_ejercicio = cursor.fetchone()[0]

                created_ejercicios.append({
                    "id_rutina_ejercicio": id_rutina_ejercicio,
                    "id_ejercicio": id_ejercicio,
                    "name": ej_row[1],
                    "orden": orden,
                    "grupo_superset": grupo_superset,
                })

            created_dias.append({
                "id_rutina_dia": id_rutina_dia,
                "nombre_dia": nombre_dia,
                "ejercicios": created_ejercicios,
            })

        # ── 4. Commit ────────────────────────────────────────────────────────
        conn.commit()

        return {
            "id_rutina": id_rutina,
            "id_usuario": id_usuario,
            "name_rutina": name_rutina.strip(),
            "fecha": fecha.isoformat(),
            "dias": created_dias,
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
            detail=f"Error al crear la rutina completa: {str(e)}",
        )
    finally:
        if conn:
            release_connection(conn)


# ── Obtener rutinas del usuario (estructura anidada completa) ─────────────────

def obtener_rutinas_usuario_service(id_usuario: int) -> list[dict]:
    """
    Devuelve todas las rutinas del usuario con su jerarquía completa:
      Rutina → Días → Ejercicios (con nombre y músculos)

    Usa un único JOIN para evitar N+1 queries.
    """
    conn = None
    try:
        conn = _get_conn()
        cursor = conn.cursor()

        cursor.execute(
            """
            SELECT
                r.id_rutina,
                r.name_rutina,
                r.fecha,
                rd.id_rutina_dia,
                rd.nombre_dia,
                re.id_rutina_ejercicio,
                re.orden,
                re.grupo_superset,
                e.id_ejercicio,
                e.name,
                e.musculos_principales,
                e.musculos_secundarios,
                e.material
            FROM rutina r
            LEFT JOIN rutina_dia rd    ON rd.id_rutina     = r.id_rutina
            LEFT JOIN rutina_ejercicio re ON re.id_rutina_dia = rd.id_rutina_dia
            LEFT JOIN ejercicios e     ON e.id_ejercicio   = re.id_ejercicio
            WHERE r.id_usuario = %s
            ORDER BY r.fecha DESC, r.id_rutina, rd.id_rutina_dia, re.orden
            """,
            (id_usuario,),
        )
        filas = cursor.fetchall()

        # Construir estructura anidada
        rutinas_map: dict[int, dict] = {}
        dias_map: dict[int, dict] = {}

        for fila in filas:
            (
                id_rutina, name_rutina, fecha,
                id_rutina_dia, nombre_dia,
                id_rutina_ejercicio, orden, grupo_superset,
                id_ejercicio, name, musculos_p, musculos_s, material,
            ) = fila

            # Rutina
            if id_rutina not in rutinas_map:
                rutinas_map[id_rutina] = {
                    "id_rutina": id_rutina,
                    "id_usuario": id_usuario,
                    "name_rutina": name_rutina,
                    "fecha": fecha.isoformat() if hasattr(fecha, "isoformat") else str(fecha),
                    "dias": [],
                }

            # Día (puede ser None si la rutina no tiene días aún)
            if id_rutina_dia is not None and id_rutina_dia not in dias_map:
                dia_dict = {
                    "id_rutina_dia": id_rutina_dia,
                    "nombre_dia": nombre_dia,
                    "ejercicios": [],
                }
                dias_map[id_rutina_dia] = dia_dict
                rutinas_map[id_rutina]["dias"].append(dia_dict)

            # Ejercicio (puede ser None si el día no tiene ejercicios)
            if id_rutina_dia is not None and id_ejercicio is not None:
                dias_map[id_rutina_dia]["ejercicios"].append({
                    "id_rutina_ejercicio": id_rutina_ejercicio,
                    "orden": orden,
                    "grupo_superset": grupo_superset,
                    "id_ejercicio": id_ejercicio,
                    "name": name,
                    "musculos_principales": musculos_p,
                    "musculos_secundarios": musculos_s,
                    "material": material,
                })

        return list(rutinas_map.values())

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener las rutinas del usuario: {str(e)}",
        )
    finally:
        if conn:
            release_connection(conn)


# ── Obtener días+ejercicios de una rutina específica ─────────────────────────

def obtener_dias_rutina_service(id_rutina: int) -> list[dict]:
    """
    Devuelve los días de una rutina con sus ejercicios.

    Reemplaza al antiguo `obtener_ejercicios_rutina_service` que usaba
    el JOIN directo rutina_ejercicio.id_rutina (FK ya no existe).
    """
    conn = None
    try:
        conn = _get_conn()
        cursor = conn.cursor()

        # Verificar que la rutina existe
        cursor.execute(
            "SELECT id_rutina FROM rutina WHERE id_rutina = %s", (id_rutina,)
        )
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"La rutina {id_rutina} no existe",
            )

        cursor.execute(
            """
            SELECT
                rd.id_rutina_dia,
                rd.nombre_dia,
                re.id_rutina_ejercicio,
                re.orden,
                re.grupo_superset,
                e.id_ejercicio,
                e.name,
                e.musculos_principales,
                e.musculos_secundarios,
                e.material
            FROM rutina_dia rd
            LEFT JOIN rutina_ejercicio re ON re.id_rutina_dia = rd.id_rutina_dia
            LEFT JOIN ejercicios e        ON e.id_ejercicio   = re.id_ejercicio
            WHERE rd.id_rutina = %s
            ORDER BY rd.id_rutina_dia, re.orden
            """,
            (id_rutina,),
        )
        filas = cursor.fetchall()

        dias_map: dict[int, dict] = {}
        for fila in filas:
            (
                id_rutina_dia, nombre_dia,
                id_rutina_ejercicio, orden, grupo_superset,
                id_ejercicio, name, musculos_p, musculos_s, material,
            ) = fila

            if id_rutina_dia not in dias_map:
                dias_map[id_rutina_dia] = {
                    "id_rutina_dia": id_rutina_dia,
                    "nombre_dia": nombre_dia,
                    "ejercicios": [],
                }

            if id_ejercicio is not None:
                dias_map[id_rutina_dia]["ejercicios"].append({
                    "id_rutina_ejercicio": id_rutina_ejercicio,
                    "orden": orden,
                    "grupo_superset": grupo_superset,
                    "id_ejercicio": id_ejercicio,
                    "name": name,
                    "musculos_principales": musculos_p,
                    "musculos_secundarios": musculos_s,
                    "material": material,
                })

        return list(dias_map.values())

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al obtener los días de la rutina: {str(e)}",
        )
    finally:
        if conn:
            release_connection(conn)

# ── Eliminar Rutina ──────────────────────────────────────────────────────────

def eliminar_rutina_service(id_rutina: int) -> dict:
    conn = None
    try:
        conn = _get_conn()
        cursor = conn.cursor()
        
        # Verificar que la rutina existe
        cursor.execute("SELECT id_rutina FROM rutina WHERE id_rutina = %s", (id_rutina,))
        if not cursor.fetchone():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Rutina no encontrada",
            )
            
        cursor.execute("DELETE FROM rutina WHERE id_rutina = %s", (id_rutina,))
        conn.commit()
        return {"message": "Rutina eliminada correctamente"}
        
    except HTTPException:
        if conn:
            conn.rollback()
        raise
    except Exception as e:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al eliminar la rutina: {str(e)}",
        )
    finally:
        if conn:
            release_connection(conn)
