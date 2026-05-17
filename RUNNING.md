# Guía de Ejecución - App Gym

## Prerequisitos

- Python 3.10+
- PostgreSQL corriendo en `localhost:5432`
- Flutter SDK instalado (para el frontend)
- Android Studio / Xcode (para emulador)

---

## 1. Backend FastAPI

### Paso 1: Activar entorno virtual

```bash
cd /home/cris/proyectos/app_gym
source .venv/bin/activate
```

### Paso 2: Verificar que PostgreSQL está corriendo

```bash
psql -h localhost -U deff -d app_gym -c "SELECT 1;"
```

Si funciona, verás:
```
 ?column?
----------
        1
(1 row)
```

Si falla, inicia PostgreSQL:
```bash
sudo systemctl start postgresql
# o si usas otro método
```

### Paso 3: Iniciar el backend

```bash
cd /home/cris/proyectos/app_gym
python Backend/main/main.py
```

Deberías ver:
```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

---

## 2. Probar Backend con curl

En otra terminal:

```bash
# Health check
curl http://localhost:8000/api/health

# Crear usuario
curl -X POST http://localhost:8000/api/usuarios \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Carlos",
    "surname": "García",
    "email": "carlos@example.com",
    "peso": 90.5,
    "altura": 186
  }'

# Obtener usuario
curl http://localhost:8000/api/usuarios/1

# Crear ejercicio
curl -X POST http://localhost:8000/api/ejercicios \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Sentadilla",
    "musculos_principales": "Piernas",
    "musculos_secundarios": "Glúteos",
    "material": "Barra",
    "tiempo_descanso": "90s"
  }'

# Listar ejercicios
curl http://localhost:8000/api/ejercicios

# Crear rutina
curl -X POST http://localhost:8000/api/rutinas \
  -H "Content-Type: application/json" \
  -d '{
    "id_usuario": 1,
    "name_rutina": "Rutina A",
    "fecha": "2024-04-28"
  }'

# Registrar entrenamiento
curl -X POST http://localhost:8000/api/usuarios/1/entrenamientos \
  -H "Content-Type: application/json" \
  -d '{
    "id_rutina": 1,
    "fecha": "2024-04-28",
    "ejercicios": [
      {
        "id_ejercicio": 1,
        "series": [
          {"peso": 100, "reps": 8},
          {"peso": 100, "reps": 8},
          {"peso": 100, "reps": 6}
        ]
      }
    ]
  }'

# Obtener entrenamientos
curl http://localhost:8000/api/usuarios/1/entrenamientos

# Registrar nutrición
curl -X POST http://localhost:8000/api/usuarios/1/nutricion \
  -H "Content-Type: application/json" \
  -d '{
    "comida": "Pollo 200g + arroz integral 150g + brócoli",
    "time": "2024-04-28T13:00:00"
  }'

# Obtener nutrición
curl http://localhost:8000/api/usuarios/1/nutricion

# Obtener recomendación del coach
curl 'http://localhost:8000/api/coach/recomendaciones?id_usuario=1'
```

---

## 3. Frontend Flutter

### Requisitos previos

```bash
flutter --version
flutter doctor
```

Asegúrate de que todo esté verde (✓).

### Paso 1: Ajustar la URL base si es necesario

**Si usas emulador Android:**
```dart
// lib/services/api_service.dart
static const _baseUrl = 'http://10.0.2.2:8000/api';  // ← Así está
```

**Si usas iOS simulador:**
```dart
static const _baseUrl = 'http://localhost:8000/api';
```

**Si usas dispositivo físico:**
```dart
// Reemplaza con tu IP de máquina:
static const _baseUrl = 'http://192.168.1.X:8000/api';
```

### Paso 2: Instalar dependencias

```bash
cd /home/cris/proyectos/app_gym/Front
flutter pub get
```

### Paso 3: Iniciar emulador

**Android:**
```bash
flutter emulators --launch Pixel_6_API_33
# o usa Android Studio
```

**iOS (en Mac):**
```bash
open -a Simulator
```

### Paso 4: Ejecutar la app

```bash
cd /home/cris/proyectos/app_gym/Front
flutter run
```

Deberías ver la app conectándose al backend en tiempo real.

---

## 4. Workflow completo

**Terminal 1 (Backend):**
```bash
cd /home/cris/proyectos/app_gym
source .venv/bin/activate
python Backend/main/main.py
```

**Terminal 2 (Pruebas curl):**
```bash
# Ejecuta los comandos curl de arriba
```

**Terminal 3 (Frontend):**
```bash
cd /home/cris/proyectos/app_gym/Front
flutter run
```

---

## Troubleshooting

### Backend no se conecta a BD
```
Error: No se pudo conectar a la base de datos
```
**Solución:** Verifica que PostgreSQL está corriendo y que las credenciales en `.env` son correctas.

### Frontend no se conecta al backend
```
ApiException: Error al conectar
```
**Solución:** 
- Verifica que el backend está en `http://0.0.0.0:8000`
- Ajusta la URL en `api_service.dart` según tu plataforma
- Verifica firewall: `sudo firewall-cmd --add-port=8000/tcp`

### El coach IA no devuelve respuesta (solo fallback local)
```
"advertencia_ia": "RuntimeError: Faltan variables de entorno de Groq"
```
**Solución:** Para usar Groq Cloud, añade a `.env`:
```
GROQ_API_KEY=tu_api_key
GROQ_ENDPOINT=https://api.groq.com/openai/v1/chat/completions
GROQ_MODEL_NAME=llama-3
```

---

## Datos de prueba recomendados

Para verificar que todo funciona:

1. **Crear usuario:**
   - Peso: 90.5 kg
   - Altura: 186 cm
   - Objetivo: 12% grasa

2. **Crear ejercicio:**
   - Sentadilla
   - Peso muerto
   - Press de banca

3. **Crear rutina:** "Rutina Fuerza"

4. **Registrar entrenamiento:** Con series reales

5. **Registrar nutrición:** Comidas del día

6. **Ver coach:** Las recomendaciones deben ser estrictas y basadas en tus datos

---

## Monitoreo

**Ver logs del backend:**
```bash
# Los logs aparecen en Terminal 1 donde ejecutaste `python Backend/main/main.py`
```

**Ver logs del Flutter:**
```bash
# Los logs aparecen en Terminal 3 donde ejecutaste `flutter run`
# O en el panel de output de Flutter en VSCode
```

**Base de datos:**
```bash
psql -h localhost -U deff -d app_gym
SELECT COUNT(*) FROM usuario;
SELECT COUNT(*) FROM entrenamiento;
SELECT * FROM nutricion ORDER BY time DESC LIMIT 5;
```
