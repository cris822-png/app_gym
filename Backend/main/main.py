from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from pydantic import BaseModel, EmailStr, Field
from datetime import date
import sys
import os

# Agregar el directorio Backend al path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.Creacion_usuario import crear_usuario_service
from services.Creaicion_rutina import crear_rutina_service
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

# ==================== Modelos Pydantic ====================

class CrearUsuarioRequest(BaseModel):
    name: str = Field(..., min_length=1, description="Nombre del usuario")
    surname: str = Field(..., min_length=1, description="Apellido del usuario")
    email: EmailStr = Field(..., description="Email del usuario")
    peso: float = Field(..., gt=0, description="Peso en kg")
    altura: float = Field(..., gt=0, description="Altura en cm")

class CrearRutinaRequest(BaseModel):
    id_usuario: int = Field(..., gt=0, description="ID del usuario propietario")
    name_rutina: str = Field(..., min_length=1, description="Nombre de la rutina")
    fecha: date = Field(..., description="Fecha de la rutina (YYYY-MM-DD)")

# ==================== Endpoints ====================

@app.post("/api/usuarios", status_code=status.HTTP_201_CREATED)
@standarize_response
async def crear_usuario(usuario: CrearUsuarioRequest):
    """
    Endpoint para crear un nuevo usuario.
    
    - **name**: Nombre del usuario (requerido)
    - **surname**: Apellido del usuario (requerido)
    - **email**: Email único del usuario (requerido)
    - **peso**: Peso en kilogramos (requerido)
    - **altura**: Altura en centímetros (requerido)
    """
    return crear_usuario_service(
        name=usuario.name,
        surname=usuario.surname,
        email=usuario.email,
        peso=usuario.peso,
        altura=usuario.altura
    )


@app.post("/api/rutinas", status_code=status.HTTP_201_CREATED)
@standarize_response
async def crear_rutina(rutina: CrearRutinaRequest):
    """
    Endpoint para crear una nueva rutina de entrenamiento.
    
    - **id_usuario**: ID del usuario propietario de la rutina (requerido)
    - **name_rutina**: Nombre de la rutina (requerido)
    - **fecha**: Fecha de la rutina en formato YYYY-MM-DD (requerido)
    """
    return crear_rutina_service(
        id_usuario=rutina.id_usuario,
        name_rutina=rutina.name_rutina,
        fecha=rutina.fecha
    )


@app.get("/api/health")
@standarize_response
async def health_check():
    """Health check endpoint"""
    return {
        "status": "ok",
        "message": "API is running"
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

