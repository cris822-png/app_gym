from __future__ import annotations

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field


class UsuarioBase(BaseModel):
    name: str = Field(..., min_length=1, description="Nombre del usuario")
    surname: str = Field(..., min_length=1, description="Apellido del usuario")
    email: EmailStr = Field(..., description="Email del usuario")
    peso: float = Field(..., gt=0, description="Peso en kg")
    altura: float = Field(..., gt=0, description="Altura en cm")
    objetivo_porcentage: Optional[str] = Field(None, description="Porcentaje objetivo de grasa")
    objetivo_peso: Optional[str] = Field(None, description="Peso objetivo")


class CrearUsuarioRequest(UsuarioBase):
    password: str = Field(..., min_length=6, max_length=100, description="Contraseña del usuario")


class ActualizarUsuarioRequest(BaseModel):
    peso: Optional[float] = Field(None, gt=0, description="Peso actual en kg")
    altura: Optional[float] = Field(None, gt=0, description="Altura en cm")
    objetivo_porcentage: Optional[str] = Field(None, description="Porcentaje objetivo de grasa")
    objetivo_peso: Optional[str] = Field(None, description="Peso objetivo")


class LoginRequest(BaseModel):
    email: EmailStr = Field(..., description="Correo electrónico del usuario")
    password: str = Field(..., min_length=6, max_length=100, description="Contraseña del usuario")


class CrearProgresoRequest(BaseModel):
    peso: float = Field(..., gt=0, description="Peso registrado en kg")


class UsuarioResponse(UsuarioBase):
    id_usuario: int
    fecha_creacion: datetime


class EjercicioDiaPayload(BaseModel):
    """Un ejercicio dentro de un día de la rutina."""
    id_ejercicio: int = Field(..., gt=0, description="ID del ejercicio")
    orden: Optional[int] = Field(None, ge=1, description="Orden del ejercicio en el día")


class DiaDtoPayload(BaseModel):
    """Un día de la rutina con sus ejercicios."""
    nombre_dia: str = Field(..., min_length=1, max_length=50, description="Nombre del día (ej. Lunes, Día A)")
    ejercicios: List[EjercicioDiaPayload] = Field(..., min_length=1, description="Ejercicios de este día")


class CrearRutinaRequest(BaseModel):
    """Payload para crear una rutina completa con 3 niveles: Rutina → Días → Ejercicios."""
    id_usuario: int = Field(..., gt=0, description="ID del usuario propietario")
    name_rutina: str = Field(..., min_length=1, description="Nombre de la rutina")
    fecha: date = Field(..., description="Fecha de la rutina (YYYY-MM-DD)")
    dias: List[DiaDtoPayload] = Field(..., min_length=1, description="Lista de días con sus ejercicios")


class RutinaResponse(BaseModel):
    id_rutina: int
    id_usuario: int
    name_rutina: str
    fecha: date


class CrearEjercicioRequest(BaseModel):
    name: str = Field(..., min_length=1, description="Nombre del ejercicio")
    musculos_principales: str = Field(..., min_length=1, description="Músculos principales")
    musculos_secundarios: Optional[str] = Field(None, description="Músculos secundarios")
    material: Optional[str] = Field(None, description="Material requerido")
    tiempo_descanso: Optional[str] = Field(None, description="Tiempo de descanso recomendado")


class EjercicioResponse(BaseModel):
    id_ejercicio: int
    name: str
    musculos_principales: str
    musculos_secundarios: Optional[str]
    material: Optional[str]
    tiempo_descanso: Optional[str]


class CrearNutricionRequest(BaseModel):
    comida: str = Field(..., min_length=1, description="Descripción de la comida")
    time: datetime = Field(..., description="Fecha y hora de la comida")


class NutricionResponse(BaseModel):
    id_nutricion: int
    id_usuario: int
    comida: str
    time: datetime


class CrearEntrenamientoSerie(BaseModel):
    peso: float = Field(..., gt=0, description="Peso utilizado en kg")
    reps: int = Field(..., gt=0, description="Repeticiones realizadas")


class CrearEntrenamientoEjercicio(BaseModel):
    id_ejercicio: int = Field(..., gt=0, description="ID del ejercicio")
    series: List[CrearEntrenamientoSerie] = Field(..., min_length=1, description="Series realizadas")


class CrearEntrenamientoRequest(BaseModel):
    id_rutina: int = Field(..., gt=0, description="ID de la rutina asociada")
    fecha: date = Field(..., description="Fecha del entrenamiento")
    ejercicios: List[CrearEntrenamientoEjercicio] = Field(..., min_length=1, description="Lista de ejercicios")


class SerieResponse(BaseModel):
    peso: float
    reps: int


class EntrenamientoEjercicioResponse(BaseModel):
    id_entrenamiento: int
    id_ejercicio: int
    nombre_ejercicio: str
    fecha: date
    series: List[SerieResponse]


class CoachRecommendationResponse(BaseModel):
    id_usuario: int
    objetivo_grasa: str
    mensaje: str
    observaciones: List[str]
    acciones: List[str]


class CrearSesionRequest(BaseModel):
    id_usuario: int = Field(..., gt=0, description="ID del usuario")
    remember_me: bool = Field(default=False, description="Si es verdadero, crea sesión persistente")
    expires_days: int = Field(default=30, description="Días para expiración de sesión")


class SesionResponse(BaseModel):
    token: str = Field(..., description="Token de sesión")
    expires_at: datetime = Field(..., description="Fecha de expiración")


class VerificarSesionRequest(BaseModel):
    token: str = Field(..., description="Token de sesión a verificar")


class SeriePayload(BaseModel):
    reps: int = Field(..., gt=0, description="Repeticiones")
    peso: Optional[float] = Field(None, gt=0, description="Peso estimado en kg")
    tiempo_descanso: Optional[str] = Field(None, description="Tiempo de descanso (ej. '60s' o '00:01:00')")


class RutinaEjercicioPayload(BaseModel):
    id_ejercicio: int = Field(..., gt=0, description="ID del ejercicio")
    series: List[SeriePayload] = Field(..., min_length=1, description="Lista de series para este ejercicio")
    orden: Optional[int] = Field(None, description="Orden/posición del ejercicio en la rutina")


class CrearRutinaResponse(BaseModel):
    id_rutina: int
    id_usuario: int
    name_rutina: str
    fecha: date
    dias: List[dict]


# ── Nuevos schemas para registro en tiempo real ─────────────────────────────

class IniciarEntrenamientoRequest(BaseModel):
    """Crea un registro en `entrenamiento` al comenzar un ejercicio.
    Devuelve id_entrenamiento para usarlo en llamadas de series."""
    id_ejercicio: int = Field(..., gt=0, description="ID del ejercicio a iniciar")
    id_rutina: Optional[int] = Field(None, gt=0, description="ID de la rutina (opcional si es entreno libre)")


class RegistrarSerieRequest(BaseModel):
    """Registra una sola serie al presionar el botón Check ✓ en la app."""
    peso: float = Field(..., gt=0, le=999, description="Peso utilizado en kg")
    reps: int   = Field(..., gt=0, le=200, description="Repeticiones realizadas")


class ChatIaRequest(BaseModel):
    """Envía un mensaje al coach IA junto al contexto del entreno activo."""
    mensaje: str  = Field(..., min_length=1, max_length=2000, description="Mensaje del usuario")
    contexto_entreno: dict = Field(
        default_factory=dict,
        description="Contexto del entreno en curso: {ejercicios:[{nombre, series_completadas:[{peso,reps}]}], duracion_minutos}"
    )


# ── Schemas para Registro Nutricional Manual ────────────────────────────────

class RegistroNutricionRequest(BaseModel):
    """Registro manual de una comida en tabla registro_nutricion."""
    comida: str = Field(..., min_length=1, max_length=255, description="Nombre de la comida")
    cantidad_g: float = Field(..., gt=0, le=9999, description="Cantidad en gramos")
    tipo_comida: str = Field(
        ...,
        description="Tipo: desayuno, almuerzo, cena, snack, postre",
    )
    fecha_consumo: datetime = Field(..., description="Fecha y hora de consumo en ISO-8601")
    detalles: Optional[str] = Field(
        None,
        max_length=1000,
        description="Ingredientes o detalles adicionales del plato (opcional)"
    )
