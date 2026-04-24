# App Gym Flutter Frontend

Este directorio contiene el esquema inicial de la app Flutter para consumir el backend FastAPI.

## Qué incluye

- `pubspec.yaml`: dependencias mínimas (`http`, `flutter`).
- `lib/main.dart`: punto de entrada con pantalla de coach.
- `lib/services/api_service.dart`: cliente HTTP que consume la API REST.
- `lib/models/*`: modelos tipados para usuario, rutina, ejercicio, nutrición, entrenamiento y recomendaciones.
- `lib/screens/coach_screen.dart`: pantalla que muestra recomendaciones de la IA y datos reales.

## Ajustes necesarios

1. Cambia `ApiService._baseUrl` si el backend no se ejecuta en el emulador Android.
   - Para Android emulador: `http://10.0.2.2:8000/api`
   - Para iOS simulador: `http://localhost:8000/api`
   - Para dispositivo físico: usa la IP de tu máquina Linux.

## Uso

```bash
cd Front
flutter pub get
flutter run
```

## Endpoints consumidos

- `GET /api/usuarios/{id_usuario}`
- `GET /api/usuarios/{id_usuario}/rutinas`
- `GET /api/usuarios/{id_usuario}/entrenamientos`
- `GET /api/usuarios/{id_usuario}/nutricion`
- `GET /api/coach/recomendaciones?id_usuario={id_usuario}`
- `POST /api/usuarios/{id_usuario}/nutricion`
- `POST /api/usuarios/{id_usuario}/entrenamientos`

## Siguiente paso

Integra aquí:
- Pantalla de creación/registro de usuario.
- Flujo de selección de rutina y ejercicios.
- Formulario de registro de nutrición y entrenamientos.
- Estado global con Provider / Riverpod.
