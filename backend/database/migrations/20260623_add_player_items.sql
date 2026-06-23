-- Add player_items table for per-player inventory sync
CREATE TABLE IF NOT EXISTS player_items (
  id TEXT NOT NULL,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  slot TEXT NOT NULL,
  tier INTEGER NOT NULL,
  set_id TEXT NOT NULL,
  power INTEGER NOT NULL,
  sell_value INTEGER NOT NULL,
  name TEXT NOT NULL,
  icon_path TEXT NOT NULL,
  is_locked BOOLEAN NOT NULL DEFAULT false,
  is_equipped BOOLEAN NOT NULL DEFAULT false,
  enchantments JSONB NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (id, player_id)
);

CREATE INDEX IF NOT EXISTS idx_player_items_player_id ON player_items(player_id);
