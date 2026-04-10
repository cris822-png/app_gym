from datetime import datetime
from functools import wraps
from fastapi.responses import JSONResponse
from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError


def standarize_response(func):
    """
    Decorador para estandarizar las respuestas de los endpoints.
    Maneja tanto respuestas exitosas como errores.
    """
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        try:
            # Ejecutar la lógica del endpoint
            result = func(*args, **kwargs)
            
            # Si es un coroutine (async), esperar resultado
            import inspect
            if inspect.iscoroutine(result):
                result = await result
            
            # Formatear respuesta exitosa
            end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            if isinstance(result, dict):
                return {
                    "start_time": start_time,
                    "end_time": end_time,
                    "status": 200,
                    "data": result,
                    "error": None
                }
            return result

        except HTTPException as e:
            # Errores controlados (400, 401, 409, etc.)
            end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            return JSONResponse(
                status_code=e.status_code,
                content={
                    "start_time": start_time,
                    "end_time": end_time,
                    "status": e.status_code,
                    "data": None,
                    "error": {
                        "code": e.status_code,
                        "message": e.detail
                    }
                }
            )
        except Exception as e:
            # Errores inesperados (500)
            end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            return JSONResponse(
                status_code=500,
                content={
                    "start_time": start_time,
                    "end_time": end_time,
                    "status": 500,
                    "data": None,
                    "error": {
                        "code": 500,
                        "message": "Error interno del servidor"
                    }
                }
            )
    return wrapper


async def custom_validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    Atrapa los errores 422 de FastAPI (campos faltantes o tipo incorrecto)
    y los transforma en nuestro formato estándar 400.
    """
    start_time = end_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Extraer los nombres de los campos que faltan
    campos_con_error = [str(err.get("loc")[-1]) for err in exc.errors()]
    
    mensaje_error = f"Faltan parámetros obligatorios o son inválidos: {', '.join(campos_con_error)}"
    
    return JSONResponse(
        status_code=400,
        content={
            "start_time": start_time,
            "end_time": end_time,
            "status": 400,
            "data": None,
            "error": {
                "code": 400,
                "message": mensaje_error
            }
        }
    )
