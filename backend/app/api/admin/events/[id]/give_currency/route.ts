import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// POST /api/admin/events/[id]/give_currency — give event currency to a player by username
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { id: eventId } = await params;

  let body: { username?: string; amount?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { username, amount } = body;
  if (!username?.trim()) return NextResponse.json({ error: 'username is required' }, { status: 400 });
  if (!amount || amount <= 0 || !Number.isInteger(amount)) {
    return NextResponse.json({ error: 'amount must be a positive integer' }, { status: 400 });
  }

  try {
    // Resolve player_id from username
    const { rows: players } = await pool.query(
      `SELECT id FROM players WHERE username = $1`,
      [username.trim()],
    );
    if (players.length === 0) return NextResponse.json({ error: 'Player not found' }, { status: 404 });
    const playerId = players[0].id;

    // Verify event exists
    const { rows: events } = await pool.query(
      `SELECT id FROM seasonal_events WHERE id = $1`,
      [eventId],
    );
    if (events.length === 0) return NextResponse.json({ error: 'Event not found' }, { status: 404 });

    // Upsert currency (add to existing balance)
    const { rows } = await pool.query(
      `INSERT INTO event_player_currency (player_id, event_id, amount)
       VALUES ($1, $2, $3)
       ON CONFLICT (player_id, event_id) DO UPDATE
         SET amount = event_player_currency.amount + EXCLUDED.amount
       RETURNING amount`,
      [playerId, eventId, amount],
    );

    return NextResponse.json({ success: true, new_balance: rows[0].amount });
  } catch (err) {
    console.error('admin give_currency POST error:', err);
    return NextResponse.json({ error: 'Failed to give currency' }, { status: 500 });
  }
}
