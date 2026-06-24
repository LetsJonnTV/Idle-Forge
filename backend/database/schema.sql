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

-- ============================================================
-- DAILY CHALLENGES
-- ============================================================
CREATE TABLE IF NOT EXISTS daily_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  kills_progress INT NOT NULL DEFAULT 0,
  crafts_progress INT NOT NULL DEFAULT 0,
  boss_progress INT NOT NULL DEFAULT 0,
  kills_claimed BOOLEAN NOT NULL DEFAULT false,
  crafts_claimed BOOLEAN NOT NULL DEFAULT false,
  boss_claimed BOOLEAN NOT NULL DEFAULT false,
  UNIQUE(player_id, date)
);
CREATE INDEX IF NOT EXISTS idx_daily_challenges_player_date ON daily_challenges(player_id, date);

ALTER TABLE daily_challenges ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all daily_challenges" ON daily_challenges FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- PRESTIGE PURCHASES
-- ============================================================
CREATE TABLE IF NOT EXISTS prestige_purchases (
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  item_id TEXT NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY(player_id, item_id)
);
CREATE INDEX IF NOT EXISTS idx_prestige_purchases_player ON prestige_purchases(player_id);

ALTER TABLE prestige_purchases ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all prestige_purchases" ON prestige_purchases FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- WORLD BOSSES
-- ============================================================
CREATE TABLE IF NOT EXISTS world_bosses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  max_hp BIGINT NOT NULL,
  current_hp BIGINT NOT NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT CHECK (status IN ('active', 'defeated', 'expired')) DEFAULT 'active'
);
CREATE INDEX IF NOT EXISTS idx_world_bosses_status ON world_bosses(status);

CREATE TABLE IF NOT EXISTS world_boss_damage (
  boss_id UUID REFERENCES world_bosses(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  damage BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (boss_id, player_id)
);
CREATE INDEX IF NOT EXISTS idx_world_boss_damage_boss ON world_boss_damage(boss_id, damage DESC);

ALTER TABLE world_bosses ENABLE ROW LEVEL SECURITY;
ALTER TABLE world_boss_damage ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all world_bosses" ON world_bosses FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all world_boss_damage" ON world_boss_damage FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- SEASONAL EVENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS seasonal_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  currency_name TEXT NOT NULL DEFAULT 'Event-Münzen',
  banner_color TEXT NOT NULL DEFAULT '#D4A84B',
  event_type TEXT CHECK (event_type IN ('collection','world_boss','forge_tournament','dungeon_rush','trade_expedition')) DEFAULT 'collection',
  type_config JSONB NOT NULL DEFAULT '{}',
  notify_on_start BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS event_shop_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  icon TEXT NOT NULL DEFAULT 'event',
  currency_cost INT NOT NULL,
  max_per_player INT NOT NULL DEFAULT 1,
  sort_order INT NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS event_player_currency (
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  event_id UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  amount INT NOT NULL DEFAULT 0,
  PRIMARY KEY(player_id, event_id)
);

CREATE TABLE IF NOT EXISTS event_player_purchases (
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  item_id UUID REFERENCES event_shop_items(id) ON DELETE CASCADE,
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY(player_id, item_id)
);

CREATE INDEX IF NOT EXISTS idx_seasonal_events_dates ON seasonal_events(starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_event_shop_items_event ON event_shop_items(event_id);
CREATE INDEX IF NOT EXISTS idx_event_player_currency_player ON event_player_currency(player_id);

-- Rank rewards (admin-configurable per event)
CREATE TABLE IF NOT EXISTS event_rank_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  rank_from INT NOT NULL,
  rank_to   INT NOT NULL,
  reward_type TEXT CHECK (reward_type IN ('gold','item')) NOT NULL,
  amount INT,
  item_id TEXT,
  leaderboard_type TEXT NOT NULL DEFAULT 'solo',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_event_rank_rewards_event ON event_rank_rewards(event_id);

-- Player scores per event (tracks participation and ranking)
CREATE TABLE IF NOT EXISTS event_player_scores (
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  event_id  UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  score     BIGINT NOT NULL DEFAULT 0,
  meta      JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (player_id, event_id)
);
CREATE INDEX IF NOT EXISTS idx_event_player_scores_event_score ON event_player_scores(event_id, score DESC);

-- Rewards distribution log (prevents double-rewarding)
CREATE TABLE IF NOT EXISTS event_rewards_distributed (
  event_id    UUID REFERENCES seasonal_events(id) ON DELETE CASCADE,
  player_id   UUID REFERENCES players(id) ON DELETE CASCADE,
  rank        INT NOT NULL,
  rewarded_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (event_id, player_id)
);

ALTER TABLE seasonal_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_player_currency ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_player_purchases ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all seasonal_events" ON seasonal_events FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all event_shop_items" ON event_shop_items FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all event_player_currency" ON event_player_currency FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all event_player_purchases" ON event_player_purchases FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER TABLE event_rank_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_player_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rewards_distributed ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all event_rank_rewards" ON event_rank_rewards FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all event_player_scores" ON event_player_scores FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all event_rewards_distributed" ON event_rewards_distributed FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- CLAN WARS (Phase 4.1)
-- ============================================================
CREATE TABLE IF NOT EXISTS clan_wars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clan_a_id UUID REFERENCES clans(id) ON DELETE CASCADE,
  clan_b_id UUID REFERENCES clans(id) ON DELETE CASCADE,
  clan_a_points INT NOT NULL DEFAULT 0,
  clan_b_points INT NOT NULL DEFAULT 0,
  winner_clan_id UUID REFERENCES clans(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT CHECK (status IN ('active', 'completed')) DEFAULT 'active'
);
CREATE INDEX IF NOT EXISTS idx_clan_wars_status ON clan_wars(status);
CREATE INDEX IF NOT EXISTS idx_clan_wars_clan_a ON clan_wars(clan_a_id);
CREATE INDEX IF NOT EXISTS idx_clan_wars_clan_b ON clan_wars(clan_b_id);

CREATE TABLE IF NOT EXISTS clan_war_contributions (
  war_id UUID REFERENCES clan_wars(id) ON DELETE CASCADE,
  player_id UUID REFERENCES players(id) ON DELETE CASCADE,
  clan_id UUID REFERENCES clans(id) ON DELETE CASCADE,
  points INT NOT NULL DEFAULT 0,
  last_contributed_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (war_id, player_id)
);
CREATE INDEX IF NOT EXISTS idx_clan_war_contributions_war ON clan_war_contributions(war_id);

ALTER TABLE clan_wars ENABLE ROW LEVEL SECURITY;
ALTER TABLE clan_war_contributions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all clan_wars" ON clan_wars FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all clan_war_contributions" ON clan_war_contributions FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- AUCTION HOUSE (Phase 4.2)
-- ============================================================
CREATE TABLE IF NOT EXISTS auctions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id UUID REFERENCES players(id) ON DELETE CASCADE,
  item_data JSONB NOT NULL,
  min_price INT NOT NULL CHECK (min_price > 0),
  buy_now_price INT CHECK (buy_now_price IS NULL OR buy_now_price > 0),
  current_bid INT NOT NULL DEFAULT 0,
  highest_bidder_id UUID REFERENCES players(id) ON DELETE SET NULL,
  claimed BOOLEAN NOT NULL DEFAULT false,
  ends_at TIMESTAMPTZ NOT NULL,
  status TEXT CHECK (status IN ('active', 'sold', 'expired', 'cancelled')) DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_auctions_status ON auctions(status, ends_at);
CREATE INDEX IF NOT EXISTS idx_auctions_seller ON auctions(seller_id);
CREATE INDEX IF NOT EXISTS idx_auctions_bidder ON auctions(highest_bidder_id);

CREATE TABLE IF NOT EXISTS auction_bids (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auction_id UUID REFERENCES auctions(id) ON DELETE CASCADE,
  bidder_id UUID REFERENCES players(id) ON DELETE CASCADE,
  amount INT NOT NULL CHECK (amount > 0),
  placed_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_auction_bids_auction ON auction_bids(auction_id, amount DESC);

ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE auction_bids ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY "Allow all auctions" ON auctions FOR ALL USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY "Allow all auction_bids" ON auction_bids FOR ALL USING (true);
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
