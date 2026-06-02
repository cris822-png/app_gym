#!/bin/bash
# Script de migración — ejecutar como superusuario de PostgreSQL
#
# Uso:
#   Opción A (si conoces la contraseña de postgres):
#     PGPASSWORD="tu_contraseña_postgres" psql -h localhost -U postgres -d app_gym -f 002_add_workout_chat.sql
#
#   Opción B (conectado localmente como el usuario postgres del sistema):
#     sudo -u postgres psql -d app_gym -f /home/cris/proyectos/app_gym/Backend/database/migrations/002_add_workout_chat.sql
#
#   Opción C (dentro de psql):
#     psql -U postgres -d app_gym
#     \i /home/cris/proyectos/app_gym/Backend/database/migrations/002_add_workout_chat.sql

echo "=== Verificando estado de la migración ==="
PGPASSWORD="|69U0[4\$zW]" psql -h localhost -U deff -d app_gym -c "
SELECT 
  CASE 
    WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='entrenamiento' AND column_name='id_rutina')
    THEN '✓ id_rutina en entrenamiento: OK'
    ELSE '✗ id_rutina en entrenamiento: FALTA → ejecutar migración como superusuario'
  END AS estado_id_rutina,
  CASE
    WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='chat_ia')
    THEN '✓ tabla chat_ia: OK'
    ELSE '✗ tabla chat_ia: FALTA → ejecutar migración como superusuario'
  END AS estado_chat_ia;
"
