import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/events/[id]/leaderboard — top 100 + calling player's rank
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { id: eventId } = await params;
  const leaderboardType = request.nextUrl.searchParams.get('leaderboard') === 'clan'
    ? 'clan'
    : 'solo';

  try {
    if (leaderboardType === 'clan') {
      const { rows: top } = await pool.query(
        `SELECT
           ecs.clan_id,
           c.name AS clan_name,
           ecs.score,
           RANK() OVER (ORDER BY ecs.score DESC) AS rank
         FROM event_clan_scores ecs
         JOIN clans c ON c.id = ecs.clan_id
         WHERE ecs.event_id = $1
         ORDER BY ecs.score DESC
         LIMIT 100`,
        [eventId],
      );

      const { rows: playerClanRows } = await pool.query<{ clan_id: string | null }>(
        `SELECT clan_id FROM players WHERE id = $1`,
        [auth.playerId],
      );
      const playerClanId = playerClanRows[0]?.clan_id;

      let own: Array<{ score: string | number; rank: string | number }> = [];
      if (playerClanId) {
        const { rows } = await pool.query(
          `SELECT score, rank FROM (
             SELECT
               clan_id,
               score,
               RANK() OVER (ORDER BY score DESC) AS rank
             FROM event_clan_scores
             WHERE event_id = $1
           ) ranked
           WHERE clan_id = $2`,
          [eventId, playerClanId],
        );
        own = rows;
      }

      return NextResponse.json({
        leaderboardType,
        leaderboard: top.map((r) => ({
          rank: Number(r.rank),
          clanId: r.clan_id,
          clanName: r.clan_name,
          score: Number(r.score),
          isMe: Boolean(playerClanId && r.clan_id === playerClanId),
        })),
        playerRank: own.length > 0
          ? { rank: Number(own[0].rank), score: Number(own[0].score) }
          : null,
      });
    }

    const { rows: top } = await pool.query(
      `SELECT
         eps.player_id,
         p.username,
         eps.score,
         RANK() OVER (ORDER BY eps.score DESC) AS rank
       FROM event_player_scores eps
       JOIN players p ON p.id = eps.player_id
       WHERE eps.event_id = $1
       ORDER BY eps.score DESC
       LIMIT 100`,
      [eventId],
    );

    const { rows: own } = await pool.query(
      `SELECT score, rank FROM (
         SELECT
           player_id,
           score,
           RANK() OVER (ORDER BY score DESC) AS rank
         FROM event_player_scores
         WHERE event_id = $1
       ) ranked
       WHERE player_id = $2`,
      [eventId, auth.playerId],
    );

    return NextResponse.json({
      leaderboardType,
      leaderboard: top.map((r) => ({
        rank: Number(r.rank),
        playerId: r.player_id,
        username: r.username,
        score: Number(r.score),
        isMe: r.player_id === auth.playerId,
      })),
      playerRank: own.length > 0 ? { rank: Number(own[0].rank), score: Number(own[0].score) } : null,
    });
  } catch (err) {
    console.error('event leaderboard GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch leaderboard' }, { status: 500 });
  }
}
