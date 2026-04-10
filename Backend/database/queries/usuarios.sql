-- Consultas SQL para la tabla usuario

-- Verificar si email existe
SELECT id_usuario FROM usuario WHERE email = %s;

-- Crear nuevo usuario
INSERT INTO usuario (name, surname, email, peso, altura, fecha_creacion)
VALUES (%s, %s, %s, %s, %s, %s)
RETURNING id_usuario;

-- Obtener usuario por ID
SELECT id_usuario, name, surname, email, peso, altura, fecha_creacion 
FROM usuario 
WHERE id_usuario = %s;

-- Obtener todos los usuarios
SELECT id_usuario, name, surname, email, peso, altura, fecha_creacion 
FROM usuario 
ORDER BY fecha_creacion DESC;

-- Actualizar usuario
UPDATE usuario 
SET name = %s, surname = %s, email = %s, peso = %s, altura = %s 
WHERE id_usuario = %s;

-- Eliminar usuario
DELETE FROM usuario WHERE id_usuario = %s;
