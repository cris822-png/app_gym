
===========================================
-- Consultas SQL para la tabla rutina

-- Verificar si usuario existe
SELECT id_usuario FROM usuario WHERE id_usuario = %s;

-- Crear nueva rutina
INSERT INTO rutina (id_usuario, name_rutina, fecha)
VALUES (%s, %s, %s)
RETURNING id_rutina;

-- Obtener rutina por ID
SELECT id_rutina, id_usuario, name_rutina, fecha 
FROM rutina 
WHERE id_rutina = %s;

-- Obtener todas las rutinas de un usuario
SELECT id_rutina, id_usuario, name_rutina, fecha 
FROM rutina 
WHERE id_usuario = %s
ORDER BY fecha DESC;

-- Obtener todas las rutinas
SELECT id_rutina, id_usuario, name_rutina, fecha 
FROM rutina 
ORDER BY fecha DESC;

-- Actualizar rutina
UPDATE rutina 
SET name_rutina = %s, fecha = %s 
WHERE id_rutina = %s;

-- Eliminar rutina
DELETE FROM rutina WHERE id_rutina = %s;

-- Eliminar todas las rutinas de un usuario
DELETE FROM rutina WHERE id_usuario = %s;
