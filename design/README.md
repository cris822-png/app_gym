# Diseño — Coach Gym IA

Este documento recoge las especificaciones del rediseño UI/UX y los assets generados (wireframes/mocks) para la aplicación *Coach Gym IA*.

## Propósito
- Centralizar el resultado del rediseño visual y las decisiones de arquitectura de interfaz.
- Proveer assets que el equipo de frontend (Flutter) y backend (Python) usará para implementar el MVP.

## Contenido del directorio `design/`
- Mockups (SVG, baja/mediana fidelidad):
  - [design/mockups/login.svg](design/mockups/login.svg)
  - [design/mockups/dashboard.svg](design/mockups/dashboard.svg)
  - [design/mockups/chat_ia.svg](design/mockups/chat_ia.svg)
  - [design/mockups/progreso.svg](design/mockups/progreso.svg)

## Resumen rápido de la propuesta (extracto)
- Navegación: Bottom navigation (Inicio, Entreno, Chat IA, Progreso, Perfil) y CTA central `Iniciar Entreno`.
- Reubicación del contenido IA: recomendaciones en tarjetas resumidas en el Dashboard y detalle en Chat IA.
- Experiencia de entrenamiento en vivo: pantalla con sets/ejercicios y WebSocket para eventos en tiempo real.

## Paleta y tipografía
- Fondo: #F7F9F7
- Primary CTA: #00A86B (verde)
- Accent: #1E88E5 (azul)
- Textos: #1F2937 (gris oscuro) y #556070 (gris medio)
- Tipografía recomendada: Inter (o Roboto si Inter no está disponible)

## Componentes clave (para implementar en Flutter)
- `CardRecommendation` — tarjeta resumen de recomendación IA
- `WorkoutCTA` — botón grande para `Iniciar Entreno`
- `ChatScreen` — lista de mensajes + tarjetas de recomendación incrustadas
- `ProgressChart` — gráfico de líneas para peso y área para % grasa

## Endpoints y modelo de datos (resumen)
- POST /api/auth/login — autenticación (JWT)
- POST /api/trainings/start — iniciar sesión de entrenamiento
- WS /ws/trainings/{session_id} — eventos en tiempo real (set_completed, heart_rate)
- GET /api/coach/recommendations?id_usuario={id} — recomendaciones actuales
- GET/POST /api/users/{id}/measurements — registros de peso/%grasa

> Nota: Ver `Backend/` para la implementación actual; asegurar UTF-8 en respuestas JSON para evitar problemas con acentos.

## Cómo previsualizar y exportar los SVG a PNG
- Abrir directamente en navegador: arrastra el archivo SVG a una pestaña del navegador.
- Exportar a PNG (ejemplos):

```bash
# Usando Inkscape
inkscape design/mockups/dashboard.svg --export-type=png --export-filename=design/mockups/dashboard.png --export-width=1080 --export-height=1920

# Usando ImageMagick (convert)
convert -density 150 design/mockups/dashboard.svg -resize 1080x1920 design/mockups/dashboard.png
```

## Próximos pasos sugeridos
- Exportar PNGs en resoluciones móvil y desktop y añadir a `design/exports/`.
- Generar componentes base en Flutter: `Scaffold` con `BottomNavigationBar`, `CardRecommendation`, `ChatComposer`.
- Implementar endpoints mínimos en backend (auth, trainings start/stop, recommendations) y pruebas E2E básicas.

---
Si quieres, exporto ahora los PNGs (móvil 360×640 y desktop 1366×768) y creo `design/exports/` con los archivos resultantes. ¿Lo hago?