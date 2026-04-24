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


class CrearUsuarioRequest(UsuarioBase):
    pass


class UsuarioResponse(UsuarioBase):
    id_usuario: int
    fecha_creacion: datetime


class CrearRutinaRequest(BaseModel):
    id_usuario: int = Field(..., gt=0, description="ID del usuario propietario")
    name_rutina: str = Field(..., min_length=1, description="Nombre de la rutina")
    fecha: date = Field(..., description="Fecha de la rutina (YYYY-MM-DD)")


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
