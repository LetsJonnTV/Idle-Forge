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

  try {
    // Top 100
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

    // Player's own rank (may be outside top 100)
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
