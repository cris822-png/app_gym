from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from datetime import date
import sys
import os

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main.schemas import (
    CrearUsuarioRequest,
    CrearRutinaRequest,
    CrearEjercicioRequest,
    CrearNutricionRequest,
    CrearEntrenamientoRequest,
)
from services.usuarios import (
    crear_usuario_service,
    obtener_usuario_service,
    obtener_progreso_usuario_service,
)
from services.rutinas import crear_rutina_service, obtener_rutinas_usuario_service
from services.ejercicios import crear_ejercicio_service, obtener_ejercicios_service
from services.nutricion import crear_nutricion_service, obtener_nutricion_usuario_service
from services.entrenamiento import registrar_entrenamiento_service, obtener_entrenamientos_usuario_service
from services.coach import generar_recomendacion_coach_service
from utils.responses import standarize_response, custom_validation_exception_handler

# Crear aplicación FastAPI
app = FastAPI(title="App Gym API", version="1.0.0")

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Registrar manejador personalizado para errores de validación
app.add_exception_handler(RequestValidationError, custom_validation_exception_handler)


@app.post("/api/usuarios", status_code=status.HTTP_201_CREATED)
@standarize_response
async def crear_usuario(usuario: CrearUsuarioRequest):
    return crear_usuario_service(
        name=usuario.name,
        surname=usuario.surname,
        email=usuario.email,
        peso=usuario.peso,
        altura=usuario.altura,
    )


@app.get("/api/usuarios/{id_usuario}")
@standarize_response
async def obtener_usuario(id_usuario: int):
    return obtener_usuario_service(id_usuario)


@app.get("/api/usuarios/{id_usuario}/progreso")
@standarize_response
async def obtener_progreso_usuario(id_usuario: int):
    return {"progreso": obtener_progreso_usuario_service(id_usuario)}


@app.post("/api/rutinas", status_code=status.HTTP_201_CREATED)
@standarize_response
async def crear_rutina(rutina: CrearRutinaRequest):
    return crear_rutina_service(
        id_usuario=rutina.id_usuario,
        name_rutina=rutina.name_rutina,
        fecha=rutina.fecha,
    )


@app.get("/api/usuarios/{id_usuario}/rutinas")
@standarize_response
async def obtener_rutinas_usuario(id_usuario: int):
    return {"rutinas": obtener_rutinas_usuario_service(id_usuario)}


@app.post("/api/ejercicios", status_code=status.HTTP_201_CREATED)
@standarize_response
async def crear_ejercicio(ejercicio: CrearEjercicioRequest):
    return crear_ejercicio_service(
        name=ejercicio.name,
        musculos_principales=ejercicio.musculos_principales,
        musculos_secundarios=ejercicio.musculos_secundarios,
        material=ejercicio.material,
        tiempo_descanso=ejercicio.tiempo_descanso,
    )


@app.get("/api/ejercicios")
@standarize_response
async def obtener_ejercicios():
    return {"ejercicios": obtener_ejercicios_service()}


@app.post("/api/usuarios/{id_usuario}/nutricion", status_code=status.HTTP_201_CREATED)
@standarize_response
async def registrar_nutricion(id_usuario: int, nutricion: CrearNutricionRequest):
    return crear_nutricion_service(
        id_usuario=id_usuario,
        comida=nutricion.comida,
        time=nutricion.time.isoformat(),
    )


@app.get("/api/usuarios/{id_usuario}/nutricion")
@standarize_response
async def obtener_nutricion(id_usuario: int):
    return {"nutricion": obtener_nutricion_usuario_service(id_usuario)}


@app.post("/api/usuarios/{id_usuario}/entrenamientos", status_code=status.HTTP_201_CREATED)
@standarize_response
async def registrar_entrenamiento(id_usuario: int, entrenamiento: CrearEntrenamientoRequest):
    return registrar_entrenamiento_service(
        id_usuario=id_usuario,
        id_rutina=entrenamiento.id_rutina,
        fecha=entrenamiento.fecha,
        ejercicios=[exercise.model_dump() for exercise in entrenamiento.ejercicios],
    )


@app.get("/api/usuarios/{id_usuario}/entrenamientos")
@standarize_response
async def obtener_entrenamientos_usuario(id_usuario: int):
    return {"entrenamientos": obtener_entrenamientos_usuario_service(id_usuario)}


@app.get("/api/coach/recomendaciones")
@standarize_response
async def obtener_recomendaciones_coach(id_usuario: int):
    return generar_recomendacion_coach_service(id_usuario)


@app.get("/api/health")
@standarize_response
async def health_check():
    return {
        "status": "ok",
        "message": "API is running",
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

