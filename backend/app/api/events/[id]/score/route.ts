import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// POST /api/events/[id]/score — add delta to player score for an event
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { id: eventId } = await params;

  let body: { delta?: number; meta?: Record<string, unknown> };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const delta = Math.floor(body.delta ?? 0);
  if (delta <= 0) return NextResponse.json({ error: 'delta must be > 0' }, { status: 400 });

  // Verify event is active
  const { rows: events } = await pool.query(
    `SELECT id FROM seasonal_events WHERE id = $1 AND starts_at <= NOW() AND ends_at > NOW()`,
    [eventId],
  );
  if (events.length === 0) return NextResponse.json({ error: 'Event not found or not active' }, { status: 404 });

  try {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows } = await client.query(
        `INSERT INTO event_player_scores (player_id, event_id, score, meta, updated_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (player_id, event_id) DO UPDATE
           SET score = event_player_scores.score + EXCLUDED.score,
               meta = COALESCE($4, event_player_scores.meta),
               updated_at = NOW()
         RETURNING score`,
        [auth.playerId, eventId, delta, JSON.stringify(body.meta ?? {})],
      );

      const { rows: playerRows } = await client.query<{ clan_id: string | null }>(
        `SELECT clan_id FROM players WHERE id = $1`,
        [auth.playerId],
      );
      const clanId = playerRows[0]?.clan_id;
      if (clanId) {
        await client.query(
          `INSERT INTO event_clan_scores (clan_id, event_id, score)
           VALUES ($1, $2, $3)
           ON CONFLICT (clan_id, event_id) DO UPDATE
             SET score = event_clan_scores.score + EXCLUDED.score`,
          [clanId, eventId, delta],
        );
      }

      await client.query('COMMIT');
      return NextResponse.json({ score: rows[0].score });
    } catch (txErr) {
      await client.query('ROLLBACK');
      throw txErr;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error('event score POST error:', err);
    return NextResponse.json({ error: 'Failed to update score' }, { status: 500 });
  }
}
