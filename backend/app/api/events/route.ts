import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/events — return all currently active events
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    const { rows: events } = await pool.query(
      `SELECT id, name, description, starts_at, ends_at, currency_name, banner_color
       FROM seasonal_events
       WHERE starts_at <= NOW() AND ends_at > NOW()
       ORDER BY ends_at ASC`,
    );

    // Get player currency for each active event
    const eventIds = events.map((e) => e.id);
    let playerCurrencies: { event_id: string; amount: number }[] = [];

    if (eventIds.length > 0) {
      const placeholders = eventIds.map((_, i) => `$${i + 2}`).join(', ');
      const { rows } = await pool.query(
        `SELECT event_id, amount FROM event_player_currency
         WHERE player_id = $1 AND event_id IN (${placeholders})`,
        [auth.playerId, ...eventIds],
      );
      playerCurrencies = rows;
    }

    const currencyMap = new Map(playerCurrencies.map((c) => [c.event_id, c.amount]));

    return NextResponse.json({
      events: events.map((e) => ({
        id: e.id,
        name: e.name,
        description: e.description,
        startsAt: e.starts_at,
        endsAt: e.ends_at,
        currencyName: e.currency_name,
        bannerColor: e.banner_color,
        playerCurrency: currencyMap.get(e.id) ?? 0,
      })),
    });
  } catch (err) {
    console.error('events GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch events' }, { status: 500 });
  }
}
