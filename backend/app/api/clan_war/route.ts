import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const WAR_DURATION_DAYS = 7;
const CONTRIBUTION_COOLDOWN_HOURS = 24;

interface ClanWarRow {
  id: string;
  clan_a_id: string;
  clan_b_id: string;
  clan_a_points: number;
  clan_b_points: number;
  winner_clan_id: string | null;
  started_at: string;
  ends_at: string;
  status: string;
  clan_a_name: string;
  clan_b_name: string;
}

async function getActiveWarForClan(clanId: string): Promise<ClanWarRow | null> {
  const { rows } = await pool.query<ClanWarRow>(
    `SELECT cw.*,
            ca.name AS clan_a_name,
            cb.name AS clan_b_name
     FROM clan_wars cw
     JOIN clans ca ON ca.id = cw.clan_a_id
     JOIN clans cb ON cb.id = cw.clan_b_id
     WHERE cw.status = 'active'
       AND cw.ends_at > NOW()
       AND (cw.clan_a_id = $1 OR cw.clan_b_id = $1)
     ORDER BY cw.started_at DESC
     LIMIT 1`,
    [clanId],
  );
  return rows[0] ?? null;
}

async function getTopContributors(warId: string, limit = 10) {
  const { rows } = await pool.query(
    `SELECT cwc.player_id, p.username, cwc.clan_id, cwc.points, cwc.last_contributed_at
     FROM clan_war_contributions cwc
     JOIN players p ON p.id = cwc.player_id
     WHERE cwc.war_id = $1
     ORDER BY cwc.points DESC
     LIMIT $2`,
    [warId, limit],
  );
  return rows;
}

// GET /api/clan_war — get current active war for the player's clan
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    // Get player's clan
    const { rows: playerRows } = await pool.query<{ clan_id: string | null; total_strength: number }>(
      `SELECT clan_id, total_strength FROM players WHERE id = $1`,
      [auth.playerId],
    );
    const player = playerRows[0];
    if (!player?.clan_id) {
      return NextResponse.json({ war: null, message: 'You are not in a clan' });
    }

    // Expire completed wars
    await pool.query(
      `UPDATE clan_wars
       SET status = 'completed',
           winner_clan_id = CASE
             WHEN clan_a_points > clan_b_points THEN clan_a_id
             WHEN clan_b_points > clan_a_points THEN clan_b_id
             ELSE NULL
           END
       WHERE status = 'active' AND ends_at <= NOW()`,
    );

    const war = await getActiveWarForClan(player.clan_id);
    if (!war) {
      return NextResponse.json({ war: null });
    }

    const contributors = await getTopContributors(war.id);

    // Player's own contribution + cooldown
    const { rows: myContrib } = await pool.query(
      `SELECT points, last_contributed_at FROM clan_war_contributions
       WHERE war_id = $1 AND player_id = $2`,
      [war.id, auth.playerId],
    );
    const myPoints = myContrib[0]?.points ?? 0;
    const lastContrib = myContrib[0]?.last_contributed_at
      ? new Date(myContrib[0].last_contributed_at)
      : null;
    const cooldownMs = CONTRIBUTION_COOLDOWN_HOURS * 3600 * 1000;
    const canContribute = !lastContrib || Date.now() - lastContrib.getTime() >= cooldownMs;
    const nextContributionAt = lastContrib
      ? new Date(lastContrib.getTime() + cooldownMs).toISOString()
      : null;

    const isPlayerClanA = war.clan_a_id === player.clan_id;

    return NextResponse.json({
      war: {
        id: war.id,
        clanA: { id: war.clan_a_id, name: war.clan_a_name, points: war.clan_a_points },
        clanB: { id: war.clan_b_id, name: war.clan_b_name, points: war.clan_b_points },
        playerClanId: player.clan_id,
        playerClanPoints: isPlayerClanA ? war.clan_a_points : war.clan_b_points,
        opponentClanPoints: isPlayerClanA ? war.clan_b_points : war.clan_a_points,
        startedAt: war.started_at,
        endsAt: war.ends_at,
        status: war.status,
      },
      myPoints,
      canContribute,
      nextContributionAt,
      playerStrength: player.total_strength,
      leaderboard: contributors.map((c, i) => ({
        rank: i + 1,
        playerId: c.player_id,
        username: c.username,
        clanId: c.clan_id,
        points: c.points,
      })),
    });
  } catch (err) {
    console.error('clan_war GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch clan war' }, { status: 500 });
  }
}

// POST /api/clan_war — contribute points to your clan's active war
// Body: {} (points are automatically = player's total_strength)
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { rows: playerRows } = await pool.query<{
      clan_id: string | null;
      total_strength: number;
    }>(
      `SELECT clan_id, total_strength FROM players WHERE id = $1`,
      [auth.playerId],
    );
    const player = playerRows[0];
    if (!player?.clan_id) {
      return NextResponse.json({ error: 'You are not in a clan' }, { status: 403 });
    }

    const war = await getActiveWarForClan(player.clan_id);
    if (!war) {
      return NextResponse.json({ error: 'No active war for your clan' }, { status: 404 });
    }

    // Cooldown check
    const { rows: contribRows } = await pool.query(
      `SELECT last_contributed_at FROM clan_war_contributions
       WHERE war_id = $1 AND player_id = $2`,
      [war.id, auth.playerId],
    );
    if (contribRows.length > 0) {
      const last = new Date(contribRows[0].last_contributed_at);
      const elapsed = Date.now() - last.getTime();
      if (elapsed < CONTRIBUTION_COOLDOWN_HOURS * 3600 * 1000) {
        const nextAt = new Date(last.getTime() + CONTRIBUTION_COOLDOWN_HOURS * 3600 * 1000);
        return NextResponse.json(
          { error: 'Already contributed today', nextContributionAt: nextAt.toISOString() },
          { status: 429 },
        );
      }
    }

    const points = Math.max(1, player.total_strength);
    const isPlayerClanA = war.clan_a_id === player.clan_id;

    await pool.query('BEGIN');
    try {
      // Upsert contribution
      await pool.query(
        `INSERT INTO clan_war_contributions (war_id, player_id, clan_id, points, last_contributed_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (war_id, player_id)
         DO UPDATE SET points = clan_war_contributions.points + EXCLUDED.points,
                       last_contributed_at = NOW()`,
        [war.id, auth.playerId, player.clan_id, points],
      );

      // Update clan points
      const column = isPlayerClanA ? 'clan_a_points' : 'clan_b_points';
      await pool.query(
        `UPDATE clan_wars SET ${column} = ${column} + $1 WHERE id = $2`,
        [points, war.id],
      );

      await pool.query('COMMIT');
    } catch (e) {
      await pool.query('ROLLBACK');
      throw e;
    }

    return NextResponse.json({
      success: true,
      pointsAdded: points,
      nextContributionAt: new Date(
        Date.now() + CONTRIBUTION_COOLDOWN_HOURS * 3600 * 1000,
      ).toISOString(),
    });
  } catch (err) {
    console.error('clan_war POST error:', err);
    return NextResponse.json({ error: 'Failed to contribute' }, { status: 500 });
  }
}

