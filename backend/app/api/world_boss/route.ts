import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { db } from '@/lib/dbClient';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const BOSS_NAMES = [
  'Molten Colossus',
  'Shadow Titan',
  'Frost Behemoth',
  'Storm Giant',
  'Void Destroyer',
  'Iron Leviathan',
];

const BOSS_DURATION_HOURS = 6;
const BASE_HP = 10_000_000;

async function getOrCreateActiveBoss() {
  // Find current active boss
  const { rows: active } = await pool.query<{
    id: string;
    name: string;
    max_hp: string;
    current_hp: string;
    started_at: string;
    ends_at: string;
    status: string;
  }>(
    `SELECT * FROM world_bosses WHERE status = 'active' AND ends_at > NOW() ORDER BY started_at DESC LIMIT 1`,
  );

  if (active.length > 0) {
    return active[0];
  }

  // Mark any stale active bosses as expired
  await pool.query(`UPDATE world_bosses SET status = 'expired' WHERE status = 'active' AND ends_at <= NOW()`);

  // Spawn new boss
  const name = BOSS_NAMES[Math.floor(Math.random() * BOSS_NAMES.length)];
  const endsAt = new Date(Date.now() + BOSS_DURATION_HOURS * 3600 * 1000);

  const { rows: created } = await pool.query(
    `INSERT INTO world_bosses (name, max_hp, current_hp, ends_at, status)
     VALUES ($1, $2, $2, $3, 'active')
     RETURNING *`,
    [name, BASE_HP, endsAt.toISOString()],
  );

  return created[0];
}

async function getTopContributors(bossId: string, limit = 10) {
  const { rows } = await pool.query(
    `SELECT wbd.player_id, p.username, wbd.damage
     FROM world_boss_damage wbd
     JOIN players p ON p.id = wbd.player_id
     WHERE wbd.boss_id = $1
     ORDER BY wbd.damage DESC
     LIMIT $2`,
    [bossId, limit],
  );
  return rows;
}

// GET /api/world_boss — get current active boss + player's damage contribution
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const boss = await getOrCreateActiveBoss();
    const contributors = await getTopContributors(boss.id);

    // Get player's contribution
    const { rows: myDamage } = await pool.query(
      `SELECT damage FROM world_boss_damage WHERE boss_id = $1 AND player_id = $2`,
      [boss.id, auth.playerId],
    );
    const playerDamage = myDamage[0]?.damage ?? 0;

    return NextResponse.json({
      boss: {
        id: boss.id,
        name: boss.name,
        maxHp: Number(boss.max_hp),
        currentHp: Number(boss.current_hp),
        startedAt: boss.started_at,
        endsAt: boss.ends_at,
        status: boss.status,
      },
      playerDamage: Number(playerDamage),
      leaderboard: contributors.map((c, i) => ({
        rank: i + 1,
        playerId: c.player_id,
        username: c.username,
        damage: Number(c.damage),
      })),
    });
  } catch (err) {
    console.error('world_boss GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch boss' }, { status: 500 });
  }
}

// POST /api/world_boss — attack the current boss
// Body: { damage: number }
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { damage?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const rawDamage = Math.floor(body.damage ?? 0);
  if (rawDamage <= 0) {
    return NextResponse.json({ error: 'damage must be > 0' }, { status: 400 });
  }

  // Cap damage per attack to prevent exploits (max 10% of boss HP)
  const cappedDamage = Math.min(rawDamage, BASE_HP * 0.1);

  try {
    const boss = await getOrCreateActiveBoss();

    if (boss.status !== 'active') {
      return NextResponse.json({ error: 'No active boss' }, { status: 409 });
    }

    // Apply damage atomically
    const { rows: updated } = await pool.query(
      `UPDATE world_bosses
       SET current_hp = GREATEST(0, current_hp - $1),
           status = CASE WHEN current_hp - $1 <= 0 THEN 'defeated' ELSE status END
       WHERE id = $2 AND status = 'active'
       RETURNING id, current_hp, status`,
      [cappedDamage, boss.id],
    );

    if (updated.length === 0) {
      return NextResponse.json({ error: 'Boss already defeated or expired' }, { status: 409 });
    }

    // Record player damage contribution (upsert)
    await pool.query(
      `INSERT INTO world_boss_damage (boss_id, player_id, damage)
       VALUES ($1, $2, $3)
       ON CONFLICT (boss_id, player_id)
       DO UPDATE SET damage = world_boss_damage.damage + EXCLUDED.damage`,
      [boss.id, auth.playerId, cappedDamage],
    );

    const newHp = Number(updated[0].current_hp);
    const newStatus = updated[0].status;

    return NextResponse.json({
      bossId: boss.id,
      newHp,
      maxHp: Number(boss.max_hp),
      status: newStatus,
      damageDealt: cappedDamage,
      defeated: newStatus === 'defeated',
    });
  } catch (err) {
    console.error('world_boss POST error:', err);
    return NextResponse.json({ error: 'Failed to attack boss' }, { status: 500 });
  }
}
