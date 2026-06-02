-- Migration 002: Add id_rutina to entrenamiento + create chat_ia table
-- Run with: psql -U postgres -d <DB_NAME> -f 002_add_workout_chat.sql

-- ============================================================
-- 1. Añadir columna id_rutina a entrenamiento (si no existe)
--    El servicio Python ya la usaba pero faltaba en el schema.
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'entrenamiento' AND column_name = 'id_rutina'
    ) THEN
        ALTER TABLE public.entrenamiento
            ADD COLUMN id_rutina INTEGER REFERENCES public.rutina(id_rutina) ON DELETE SET NULL;
        RAISE NOTICE 'Columna id_rutina añadida a entrenamiento.';
    ELSE
        RAISE NOTICE 'Columna id_rutina ya existe en entrenamiento, se omite.';
    END IF;
END
$$;

-- ============================================================
-- 2. Crear tabla chat_ia para historial de conversaciones IA
-- ============================================================
CREATE TABLE IF NOT EXISTS public.chat_ia (
    id_mensaje          SERIAL PRIMARY KEY,
    id_usuario          INTEGER NOT NULL REFERENCES public.usuario(id_usuario) ON DELETE CASCADE,
    rol                 VARCHAR(10) NOT NULL CHECK (rol IN ('user', 'assistant')),
    contenido           TEXT NOT NULL,
    created_at          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    id_entreno_contexto INTEGER REFERENCES public.entrenamiento(id_entrenamiento) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_chat_ia_usuario     ON public.chat_ia(id_usuario);
CREATE INDEX IF NOT EXISTS idx_chat_ia_created_at  ON public.chat_ia(id_usuario, created_at DESC);

GRANT ALL ON TABLE public.chat_ia TO deff;
GRANT ALL ON SEQUENCE public.chat_ia_id_mensaje_seq TO deff;
