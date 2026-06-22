-- Add Google OAuth support to players table
-- Created: 2026-06-22

ALTER TABLE players ADD COLUMN IF NOT EXISTS google_id VARCHAR(255) UNIQUE;
ALTER TABLE players ADD COLUMN IF NOT EXISTS email VARCHAR(255) UNIQUE;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_players_google_id ON players(google_id);
CREATE INDEX IF NOT EXISTS idx_players_email ON players(email);
