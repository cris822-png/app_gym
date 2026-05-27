-- Migration: Add peso column to usuario and create sessions table
-- Date: 2026-05-25

-- 1. Add peso column to usuario table if it doesn't exist
ALTER TABLE usuario 
ADD COLUMN IF NOT EXISTS peso numeric(5,2);

-- 2. Create sessions table for "Remember me 30 days" feature
CREATE TABLE IF NOT EXISTS sessions (
    id_sesion SERIAL PRIMARY KEY,
    id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
    token VARCHAR(256) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 3. Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sessions_usuario ON sessions(id_usuario);
CREATE INDEX IF NOT EXISTS idx_sessions_active_expiry ON sessions(is_active, expires_at);

-- Verify tables
SELECT 'usuario columns:' as info;
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'usuario' ORDER BY ordinal_position;

SELECT 'sessions table:' as info;
SELECT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_name = 'sessions'
) as sessions_exists;
