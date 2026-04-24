import sys
import os
import json
from datetime import date, datetime, timedelta
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from dotenv import load_dotenv
from fastapi import HTTPException, status

load_dotenv()

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def _obtener_usuario(id_usuario: int) -> dict:
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
    finally:
        if conn:
            release_connection(conn)


def _obtener_rutinas(id_usuario: int) -> list[dict]:
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id_rutina, name_rutina, fecha FROM rutina WHERE id_usuario = %s ORDER BY fecha DESC",
            (id_usuario,)
        )
        return [
            {"id_rutina": fila[0], "name_rutina": fila[1], "fecha": fila[2].isoformat() if hasattr(fila[2], "isoformat") else str(fila[2])}
            for fila in cursor.fetchall()
        ]
    finally:
        if conn:
            release_connection(conn)


def _obtener_entrenamientos(id_usuario: int) -> list[dict]:
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )
        cursor = conn.cursor()
        cursor.execute(
            "SELECT e.id_entrenamiento, e.id_ejercicio, ex.name, e.fecha "
            "FROM entrenamiento e JOIN ejercicios ex ON e.id_ejercicio = ex.id_ejercicio "
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
    finally:
        if conn:
            release_connection(conn)


def _obtener_nutricion(id_usuario: int) -> list[dict]:
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )
        cursor = conn.cursor()
        cursor.execute("SELECT comida, time FROM nutricion WHERE id_usuario = %s ORDER BY time DESC", (id_usuario,))
        return [
            {"comida": fila[0], "time": fila[1].isoformat() if hasattr(fila[1], "isoformat") else str(fila[1])}
            for fila in cursor.fetchall()
        ]
    finally:
        if conn:
            release_connection(conn)


def _obtener_progreso(id_usuario: int) -> list[dict]:
    conn = None
    try:
        conn = connect_bbdd_pgsql(
            host=os.getenv("DB_HOST"),
            database=os.getenv("DB_NAME"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD")
        )
        cursor = conn.cursor()
        cursor.execute("SELECT peso, date, objetivo FROM progreso_usuario WHERE id_usuario = %s ORDER BY date DESC", (id_usuario,))
        return [
            {"peso": fila[0], "date": fila[1].isoformat() if hasattr(fila[1], "isoformat") else str(fila[1]), "objetivo": fila[2]}
            for fila in cursor.fetchall()
        ]
    finally:
        if conn:
            release_connection(conn)


def _calcular_frecuencia(entrenamientos: list[dict]) -> int:
    fechas = {item["fecha"] for item in entrenamientos}
    return len(fechas)


def _analizar_progresion(entrenamientos: list[dict]) -> list[str]:
    ejercicios = {}
    for item in entrenamientos:
        nombre = item["nombre_ejercicio"]
        total_load = sum(s["peso"] * s["reps"] for s in item["series"])
        ejercicios.setdefault(nombre, []).append({
            "fecha": item["fecha"],
            "total_load": total_load,
            "max_peso": max(s["peso"] for s in item["series"])
        })

    observaciones = []
    for nombre, sesiones in ejercicios.items():
        if len(sesiones) < 2:
            observaciones.append(f"No hay suficiente historial para evaluar la progresión en {nombre}.")
            continue

        actual = sesiones[0]
        previo = sesiones[1]
        if actual["total_load"] <= previo["total_load"]:
            observaciones.append(
                f"La carga total en {nombre} no crece. Último volumen {actual['total_load']:.1f} vs previo {previo['total_load']:.1f}. Aumenta 2.5-5 kg en las series clave y mantén el rango de 4-6 reps."
            )
        else:
            observaciones.append(
                f"Bien: {nombre} muestra progreso. Último volumen {actual['total_load']:.1f}. Sigue aumentando carga en 5% cada 7-10 días si la técnica es sólida."
            )
    return observaciones


def _analizar_nutricion(nutricion: list[dict]) -> list[str]:
    if not nutricion:
        return [
            "No hay registros de nutrición. Si quieres 12% grasa, necesitas un control estricto de comidas reales y no inventos.",
            "Registra proteína, carbohidratos limpios y grasas limpias en cada comida."
        ]

    entradas = nutricion[:5]
    comidas = ", ".join([f"{item['comida']}" for item in entradas])
    return [
        f"Últimos alimentos registrados: {comidas}.",
        "Si tu objetivo es definición, prioriza proteína alta y no pases más de 2 comidas con carbohidratos densos después de las 20:00.",
        "Si no hay alimentos claros, el feedback será malo: registra con precisión calorías y macros la próxima semana."
    ]


def _generar_mensaje_directo(usuario: dict, rutinas: list[dict], frecuencia: int, progresion: list[str], nutricion: list[str], progreso: list[dict]) -> str:
    if frecuencia < 4:
        recomendacion_frecuencia = "No puedes pretender 12% grasa con 2 o 3 sesiones por semana. Necesitas al menos 4-5 entrenamientos con foco de fuerza y déficit calibrado."
    else:
        recomendacion_frecuencia = "La frecuencia es aceptable, pero no sirvo para halagar: si las cargas no suben, estás desperdiciando horas en el gym."

    meta = "12% de grasa corporal"
    resumen = (
        f"Tienes {usuario['peso']} kg y {usuario['altura']} cm. Tu objetivo es {meta}."
        f" Hay {len(rutinas)} rutinas en el sistema."
    )
    if progreso:
        ultimo = progreso[0]
        resumen += f" Último registro: {ultimo['peso']} kg con objetivo '{ultimo['objetivo']}'."

    return (
        f"{resumen} {recomendacion_frecuencia} "
        "No permitas excusas: carga el gimnasio con trabajo compuesto, prioriza las sentadillas, press y peso muerto de tu rutina, y haz seguimiento real de cada semana."
    )


def _construir_prompt(usuario: dict, rutinas: list[dict], entrenamientos: list[dict], nutricion: list[dict], progreso: list[dict]) -> str:
    prompt = [
        "Eres un coach/nutricionista serio y directo. No halagues."
        "Analiza estos datos de entrenamiento y nutrición reales y genera recomendaciones estrictas y específicas para un objetivo de 12% de grasa corporal."
        f"Usuario: {usuario['name']} {usuario['surname']}, {usuario['peso']} kg, {usuario['altura']} cm."
    ]
    if progreso:
        prompt.append(f"Historial de peso / objetivo: {progreso[0]['peso']} kg, objetivo {progreso[0]['objetivo']}.")
    prompt.append(f"Rutinas registradas: {len(rutinas)}.")
    prompt.append(f"Entrenamientos recientes: {len(entrenamientos)} registros.")
    if nutricion:
        prompt.append(f"Nutrición reciente: {len(nutricion)} entradas.")
        prompt.append("Ejemplos de comidas: " + "; ".join([item['comida'] for item in nutricion[:3]]))
    for idx, item in enumerate(entrenamientos[:4], 1):
        prompt.append(f"Entrenamiento {idx}: {item['nombre_ejercicio']} - series: {', '.join(str(s['peso']) + 'kgx' + str(s['reps']) for s in item['series'])}.")
    prompt.append(
        "Devuelve una sola respuesta con: 1) qué corregir ya, 2) qué mantener, 3) prioridades de sobrecarga progresiva y dieta."
    )
    return "\n".join(prompt)


def _call_groq(prompt: str) -> str:
    api_key = os.getenv("GROQ_API_KEY")
    endpoint = os.getenv("GROQ_ENDPOINT")
    model = os.getenv("GROQ_MODEL_NAME", "llama-3")
    if not api_key or not endpoint:
        raise RuntimeError("Faltan variables de entorno de Groq: GROQ_API_KEY o GROQ_ENDPOINT")

    payload = json.dumps({
        "model": model,
        "input": prompt,
        "max_output_tokens": 400,
        "temperature": 0.3
    }).encode("utf-8")

    request = Request(
        endpoint,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
    )
    try:
        with urlopen(request, timeout=20) as response:
            response_data = json.loads(response.read().decode("utf-8"))
            if "output" in response_data and isinstance(response_data["output"], list):
                return response_data["output"][0].get("content", response_data["output"][0])
            return response_data.get("text", json.dumps(response_data))
    except HTTPError as exc:
        raise RuntimeError(f"Error de Groq: {exc.code} {exc.reason}")
    except URLError as exc:
        raise RuntimeError(f"Error de conexión a Groq: {exc.reason}")


def generar_recomendacion_coach_service(id_usuario: int) -> dict:
    usuario = _obtener_usuario(id_usuario)
    rutinas = _obtener_rutinas(id_usuario)
    entrenamientos = _obtener_entrenamientos(id_usuario)
    nutricion = _obtener_nutricion(id_usuario)
    progreso = _obtener_progreso(id_usuario)

    frecuencia = _calcular_frecuencia(entrenamientos)
    observaciones = _analizar_progresion(entrenamientos)
    observaciones.extend(_analizar_nutricion(nutricion))
    mensaje = _generar_mensaje_directo(usuario, rutinas, frecuencia, observaciones, nutricion, progreso)

    response = {
        "id_usuario": id_usuario,
        "objetivo_grasa": "12%",
        "mensaje": mensaje,
        "observaciones": observaciones,
        "acciones": [
            "Registra cada entrenamiento con peso y reps exactas.",
            "Aumenta la carga en ejercicios compuestos cada 7-10 días.",
            "No pases de 2 comidas con carbohidratos densos después de las 20:00."
        ]
    }

    try:
        if os.getenv("GROQ_API_KEY") and os.getenv("GROQ_ENDPOINT"):
            prompt = _construir_prompt(usuario, rutinas, entrenamientos, nutricion, progreso)
            response_text = _call_groq(prompt)
            response["mensaje"] = response_text
            response["fuente"] = "groq"
    except Exception as exc:
        response["advertencia_ia"] = str(exc)

    return response
