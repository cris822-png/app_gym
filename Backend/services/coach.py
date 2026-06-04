import sys
import os
import json
from datetime import date, datetime
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError
from dotenv import load_dotenv
from fastapi import HTTPException, status

dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path)

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.configs.pgsql_connection import connect_bbdd_pgsql, release_connection


def _usuario_tiene_columna_peso(cursor) -> bool:
    cursor.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_name = 'usuario' AND column_name = 'peso'"
    )
    return cursor.fetchone() is not None


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
        cursor.execute("SELECT comida, fecha_hora FROM nutricion WHERE id_usuario = %s ORDER BY fecha_hora DESC", (id_usuario,))
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
        cursor.execute("SELECT peso, fecha FROM progreso_usuario WHERE id_usuario = %s ORDER BY fecha DESC", (id_usuario,))
        return [
            {"peso": fila[0], "date": fila[1].isoformat() if hasattr(fila[1], "isoformat") else str(fila[1])}
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
        series_con_datos = item["series"]
        # Tratar peso=None como 0 (series de plantilla sin registro real aún)
        total_load = sum((s["peso"] or 0) * (s["reps"] or 0) for s in series_con_datos)
        pesos = [(s["peso"] or 0) for s in series_con_datos]
        ejercicios.setdefault(nombre, []).append({
            "fecha": item["fecha"],
            "total_load": total_load,
            "max_peso": max(pesos) if pesos else 0
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
        resumen += f" Último registro: {ultimo['peso']} kg."

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
        prompt.append(f"Historial de peso: {progreso[0]['peso']} kg.")
    prompt.append(f"Rutinas registradas: {len(rutinas)}.")
    prompt.append(f"Entrenamientos recientes: {len(entrenamientos)} registros.")
    if nutricion:
        prompt.append(f"Nutrición reciente: {len(nutricion)} entradas.")
        prompt.append("Ejemplos de comidas: " + "; ".join([item['comida'] for item in nutricion[:3]]))
    for idx, item in enumerate(entrenamientos[:4], 1):
        series_str = ", ".join(
            f"{s['peso'] or 0}kgx{s['reps'] or 0}"
            for s in item["series"]
        )
        prompt.append(f"Entrenamiento {idx}: {item['nombre_ejercicio']} - series: {series_str}.")
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


# ── Chat IA conversacional con contexto del entreno activo ───────────────────

def _call_groq_chat(messages: list[dict]) -> str:
    """
    Llama a Groq usando el endpoint /openai/v1/chat/completions (formato OpenAI).
    A diferencia de _call_groq, este soporta historial de mensajes y system prompt.
    El modelo correcto para Groq es 'llama-3.3-70b-versatile' o similar.
    """
    api_key = os.getenv("GROQ_API_KEY")
    model   = os.getenv("GROQ_MODEL_NAME", "llama-3.3-70b-versatile")

    if not api_key:
        raise RuntimeError("Falta GROQ_API_KEY en las variables de entorno")

    payload = json.dumps({
        "model": model,
        "messages": messages,
        "max_tokens": 400,
        "temperature": 0.7
    }).encode("utf-8")

    request = Request(
        "https://api.groq.com/openai/v1/chat/completions",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }
    )
    try:
        with urlopen(request, timeout=25) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data["choices"][0]["message"]["content"]
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Error Groq {exc.code}: {body}")
    except URLError as exc:
        raise RuntimeError(f"Error de conexión a Groq: {exc.reason}")


def chat_ia_service(id_usuario: int, mensaje: str, contexto_entreno: dict) -> dict:
    """
    Chat conversacional con el coach IA.

    Flujo:
    1. Obtiene perfil del usuario (tabla `usuario`)
    2. Recupera historial reciente de `chat_ia` (últimos 10 mensajes)
    3. Construye system_prompt con datos del usuario + contexto del entreno activo
    4. Llama al LLM con historial + nuevo mensaje
    5. Persiste user message y respuesta del asistente en `chat_ia`

    Tablas:  usuario (SELECT) + chat_ia (SELECT + INSERT ×2)
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

        # 1. Perfil del usuario
        usuario = _obtener_usuario(id_usuario)

        # 2. Historial de chat (últimos 10, cronológico)
        cursor.execute("""
            SELECT rol, contenido
            FROM chat_ia
            WHERE id_usuario = %s
            ORDER BY created_at DESC
            LIMIT 10
        """, (id_usuario,))
        historial_raw = cursor.fetchall()
        # Invertir para cronología ascendente
        historial = [{"role": r[0], "content": r[1]} for r in reversed(historial_raw)]

        # 3. Construir contexto del entreno en texto
        ejercicios_texto = ""
        ejercicios_activos = contexto_entreno.get("ejercicios", [])
        if ejercicios_activos:
            lineas = []
            for ej in ejercicios_activos:
                series_str = ", ".join(
                    f"{s['peso']}kg×{s['reps']}reps"
                    for s in ej.get("series_completadas", [])
                ) or "sin series aún"
                lineas.append(f"  • {ej['nombre']}: {series_str}")
            ejercicios_texto = "\n".join(lineas)
        else:
            ejercicios_texto = "  • Sin ejercicios registrados todavía."

        duracion = contexto_entreno.get("duracion_minutos", 0)

        # System prompt con contexto completo
        objetivo = usuario.get("objetivo_porcentage") or "sin definir"
        system_prompt = (
            f"Eres un coach de fitness experto, conciso y motivador. Respondes en español.\n"
            f"No alagues innecesariamente. Da consejos prácticos y directos.\n\n"
            f"PERFIL DEL USUARIO:\n"
            f"  Nombre: {usuario['name']} {usuario['surname']}\n"
            f"  Peso: {usuario['peso']} kg | Altura: {usuario['altura']} cm\n"
            f"  Objetivo: {objetivo}\n\n"
            f"ENTRENO ACTIVO AHORA MISMO (duración: {duracion} min):\n"
            f"{ejercicios_texto}\n\n"
            f"Reglas: Responde en máximo 3-4 frases. Usa los datos del entreno activo si son relevantes."
        )

        # 4. Construir lista de messages para el LLM
        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(historial)
        messages.append({"role": "user", "content": mensaje})

        # 5. Guardar mensaje del usuario en DB
        cursor.execute(
            "INSERT INTO chat_ia (id_usuario, rol, contenido) VALUES (%s, 'user', %s)",
            (id_usuario, mensaje)
        )

        # 6. Llamar al LLM
        try:
            respuesta = _call_groq_chat(messages)
        except Exception as exc:
            # Fallback si Groq no está disponible
            respuesta = (
                "Lo siento, el coach IA no está disponible en este momento. "
                "Revisa tu GROQ_API_KEY y vuelve a intentarlo."
            )

        # 7. Guardar respuesta del asistente en DB
        cursor.execute(
            "INSERT INTO chat_ia (id_usuario, rol, contenido) VALUES (%s, 'assistant', %s)",
            (id_usuario, respuesta)
        )
        conn.commit()

        return {"respuesta": respuesta}

    except HTTPException:
        if conn:
            conn.rollback()
        raise
    except Exception as exc:
        if conn:
            conn.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error en el chat IA: {str(exc)}"
        )
    finally:
        if conn:
            release_connection(conn)
