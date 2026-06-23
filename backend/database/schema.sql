-- Idle Forge PostgreSQL schema
-- Apply this schema to your PostgreSQL database.
-- RLS statements remain for compatibility and can be enabled where needed.

-- ============================================================
-- CLANS (must be created before PLAYERS due to FK)
-- ============================================================
CREATE TABLE IF NOT EXISTS clans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  leader_id UUID, -- FK to players added below
  level INT DEFAULT 1,
  xp INT DEFAULT 0,
  description TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PLAYERS
-- ============================================================
CREATE TABLE IF NOT EXISTS players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  total_strength INT DEFAULT 0,
  prestige_level INT DEFAULT 0,
  chapter INT DEFAULT 1,
  clan_id UUID REFERENCES clans(id) ON DELETE SET NULL,
  is_admin BOOLEAN DEFAULT false,
  is_blocked BOOLEAN DEFAULT false
);

-- Add FK on clans.leader_id now that players exists (idempotent)
DO $$ BEGIN
  ALTER TABLE clans ADD CONSTRAINT clans_leader_id_fkey
    FOREIGN KEY (leader_id) REFERENCES players(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- FRIENDS
-- ============================================================
CREATE TABLE IF NOT EXISTS friends (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id UUID REFERENCES players(id) ON DELETE CASCADE,
  addressee_id UUID REFERENCES players(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('pending', 'accepted', 'blocked')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requester_id, addressee_id)
);

-- ============================================================
-- CLAN MEMBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS clan_members (
  clan_id UUID REFERENCES clans(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (clan_id, player_id)
);

-- ============================================================
-- PVP BATTLES
-- ============================================================
CREATE TABLE IF NOT EXISTS pvp_battles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id UUID REFERENCES players(id) ON DELETE CASCADE,
  defender_id UUID REFERENCES players(id) ON DELETE CASCADE,
  winner_id UUID REFERENCES players(id) ON DELETE SET NULL,
  challenger_strength INT NOT NULL,
  defender_strength INT NOT NULL,
  status TEXT CHECK (status IN ('pending', 'completed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- COOP SESSIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS coop_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id UUID REFERENCES players(id) ON DELETE CASCADE,
  guest_id UUID REFERENCES players(id) ON DELETE SET NULL,
  boss_hp INT DEFAULT 1000,
  status TEXT CHECK (status IN ('waiting', 'active', 'completed')) DEFAULT 'waiting',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- GAME SAVES
-- ============================================================
CREATE TABLE IF NOT EXISTS game_saves (
  player_id UUID PRIMARY KEY REFERENCES players(id) ON DELETE CASCADE,
  save_data JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- PLAYER ITEMS (inventory sync)
-- ============================================================
CREATE TABLE IF NOT EXISTS player_items (
  id TEXT NOT NULL,
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  slot TEXT NOT NULL,
  tier TEXT NOT NULL,
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

-- ============================================================
-- LEADERBOARD VIEW
-- ============================================================
CREATE OR REPLACE VIEW leaderboard AS
  SELECT id, username, total_strength, prestige_level, chapter
  FROM players
  ORDER BY total_strength DESC
  LIMIT 100;

-- ============================================================
-- INDEXES (performance)
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_players_username ON players(username);
CREATE INDEX IF NOT EXISTS idx_players_total_strength ON players(total_strength DESC);
CREATE INDEX IF NOT EXISTS idx_friends_requester ON friends(requester_id);
CREATE INDEX IF NOT EXISTS idx_friends_addressee ON friends(addressee_id);
CREATE INDEX IF NOT EXISTS idx_pvp_challenger ON pvp_battles(challenger_id);
CREATE INDEX IF NOT EXISTS idx_pvp_defender ON pvp_battles(defender_id);
CREATE INDEX IF NOT EXISTS idx_coop_host ON coop_sessions(host_id);
CREATE INDEX IF NOT EXISTS idx_coop_status ON coop_sessions(status);

-- ============================================================
-- ROW LEVEL SECURITY for GAME SAVES
-- ============================================================
ALTER TABLE game_saves ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Allow all game_saves" ON game_saves FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- ROW LEVEL SECURITY
-- Enable RLS and add policies for each table.
-- Players can only update their own row.
-- ============================================================
ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE clans ENABLE ROW LEVEL SECURITY;
ALTER TABLE clan_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE pvp_battles ENABLE ROW LEVEL SECURITY;
ALTER TABLE coop_sessions ENABLE ROW LEVEL SECURITY;

-- Anon key can SELECT (needed for server-side queries with service role bypass)
-- The Next.js backend uses the anon key but all auth is done via JWT at API layer.
-- For full production: use service_role key in backend, anon key for client-only reads.

DO $$ BEGIN
  CREATE POLICY "Public read players" ON players FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow insert players" ON players FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read clans" ON clans FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
-- Note: leaderboard is a view on players; it inherits players' RLS policies.

DO $$ BEGIN
  CREATE POLICY "Allow select pvp_battles" ON pvp_battles FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow insert pvp_battles" ON pvp_battles FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY "Allow select coop_sessions" ON coop_sessions FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow insert coop_sessions" ON coop_sessions FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow update coop_sessions" ON coop_sessions FOR UPDATE USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PENDING REWARDS (Admin → Player real-time gifts)
-- ============================================================
CREATE TABLE IF NOT EXISTS pending_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  reward_type TEXT CHECK (reward_type IN ('gold', 'item')) NOT NULL,
  amount INT,
  item_id TEXT,
  given_by UUID REFERENCES players(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pending_rewards_player ON pending_rewards(player_id);

ALTER TABLE pending_rewards ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all pending_rewards" ON pending_rewards FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Migration: add is_admin / is_blocked to existing players table (idempotent)
DO $$ BEGIN
  ALTER TABLE players ADD COLUMN is_admin BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE players ADD COLUMN is_blocked BOOLEAN DEFAULT false;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE players ADD COLUMN google_id VARCHAR(255) UNIQUE;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;
DO $$ BEGIN
  ALTER TABLE players ADD COLUMN email VARCHAR(255) UNIQUE;
EXCEPTION WHEN duplicate_column THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS idx_players_google_id ON players(google_id);
CREATE INDEX IF NOT EXISTS idx_players_email ON players(email);

CREATE TABLE IF NOT EXISTS clan_chat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_id UUID REFERENCES clans(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  username TEXT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_clan_chat_clan_id ON clan_chat(clan_id, created_at DESC);

-- ============================================================
-- CLAN INVITES
-- ============================================================
CREATE TABLE IF NOT EXISTS clan_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_id UUID REFERENCES clans(id) ON DELETE CASCADE,
  invitee_id UUID REFERENCES players(id) ON DELETE CASCADE,
  inviter_id UUID REFERENCES players(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('pending', 'accepted', 'declined')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(clan_id, invitee_id)
);

-- ============================================================
-- ITEM BLUEPRINTS
-- ============================================================
CREATE TABLE IF NOT EXISTS item_blueprints (
  id TEXT PRIMARY KEY,
  slot TEXT NOT NULL,
  name TEXT NOT NULL,
  base_power INT NOT NULL,
  icon_path TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_item_blueprints_slot ON item_blueprints(slot);
CREATE INDEX IF NOT EXISTS idx_item_blueprints_active ON item_blueprints(is_active);

ALTER TABLE item_blueprints ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Public read item_blueprints" ON item_blueprints FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all item_blueprints" ON item_blueprints FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- RLS for new tables
-- ============================================================
ALTER TABLE clan_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE clan_invites ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "Public read clan_chat" ON clan_chat FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow insert clan_chat" ON clan_chat FOR INSERT WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Public read clan_invites" ON clan_invites FOR SELECT USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all clan_invites" ON clan_invites FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
