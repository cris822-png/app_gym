# App Gym API

API REST para gestionar usuarios y rutinas de entrenamiento en un gimnasio.

## 🚀 Características

- ✅ Gestión de usuarios (crear, validar email único)
- ✅ Gestión de rutinas (crear, asociar a usuarios)
- ✅ Respuestas estandarizadas con timestamps
- ✅ Manejo de errores con códigos HTTP específicos
- ✅ Validación de datos con Pydantic
- ✅ Pool de conexiones de base de datos
- ✅ CORS habilitado

## 📁 Estructura del Proyecto

```
Backend/
├── database/
│   ├── configs/
│   │   └── pgsql_connection.py    # Configuración de conexión BD
│   └── queries/
│       └── usuarios.sql           # Consultas SQL
├── services/
│   ├── Creacion_usuario.py        # Servicio de usuarios
│   └── Creaicion_rutina.py        # Servicio de rutinas
├── utils/
│   └── responses.py               # Decorador de respuestas estandarizadas
└── main/
    └── main.py                    # Servidor FastAPI y endpoints
```

## 🛠️ Instalación

### 1. Clonar repositorio y crear entorno virtual
```bash
cd /home/cris/proyectos/app_gym
python -m venv .venv
source .venv/bin/activate
```

### 2. Instalar dependencias
```bash
pip install -r requirements.txt
```

### 3. Configurar variables de entorno
```bash
cp .env.example .env
# Editar .env con tus credenciales de BD
```

## 🏃 Ejecución

```bash
python Backend/main/main.py
```

La API estará disponible en: `http://localhost:8000`

## 📚 Documentación

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Documentación API**: Ver `API_DOCUMENTATION.md`
- **Formato de Respuestas**: Ver `RESPONSE_FORMAT.md`

## 🧪 Testing

Ejecutar el script de pruebas:
```bash
bash test_endpoints.sh
```

## 📋 Endpoints Principales

### Usuarios
- `POST /api/usuarios` - Crear nuevo usuario
- `GET /api/health` - Verificar estado de la API

### Rutinas
- `POST /api/rutinas` - Crear nueva rutina

## 🔒 Base de Datos

### Tabla: usuario
```sql
id_usuario (integer) - PK
name (varchar)
surname (varchar)
email (varchar) - UNIQUE
peso (numeric)
altura (numeric)
fecha_creacion (timestamp)
```

### Tabla: rutina
```sql
id_rutina (integer) - PK
id_usuario (integer) - FK usuario
name_rutina (varchar)
fecha (date)
```

## 🔄 Flujo de Respuestas

Todos los endpoints responden con este formato:

```json
{
  "start_time": "2026-04-10 10:30:45",
  "end_time": "2026-04-10 10:30:46",
  "status": 200,
  "data": { /* datos del endpoint */ },
  "error": null
}
```

En caso de error:

```json
{
  "start_time": "2026-04-10 10:30:45",
  "end_time": "2026-04-10 10:30:46",
  "status": 400,
  "data": null,
  "error": {
    "code": 400,
    "message": "Descripción del error"
  }
}
```

## 📝 Variables de Entorno (.env)

```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=app_gym
DB_USER=deff
DB_PASSWORD=|69U0[4$zW]

API_HOST=0.0.0.0
API_PORT=8000
API_ENV=development
```

## 🐛 Troubleshooting

### No se puede conectar a la BD
- Verificar que PostgreSQL está ejecutándose
- Validar credenciales en .env
- Revisar que la base de datos `app_gym` existe

### Error: ModuleNotFoundError
- Asegurar que está en el directorio correcto
- Verificar que el entorno virtual está activado
- Reinstalar dependencias: `pip install -r requirements.txt`

## 📞 Soporte

Para reportar errores o sugerencias, contactar al equipo de desarrollo.
