-- Idle Forge — Supabase Schema
-- Run this in Supabase SQL Editor (Dashboard > SQL Editor)
-- Enable RLS on all tables after creation.

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
  clan_id UUID REFERENCES clans(id) ON DELETE SET NULL
);

-- Add FK on clans.leader_id now that players exists
ALTER TABLE clans
  ADD CONSTRAINT clans_leader_id_fkey
  FOREIGN KEY (leader_id) REFERENCES players(id) ON DELETE SET NULL;

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

CREATE POLICY "Public read players" ON players FOR SELECT USING (true);
CREATE POLICY "Public read clans" ON clans FOR SELECT USING (true);
CREATE POLICY "Public read leaderboard" ON leaderboard FOR SELECT USING (true);
