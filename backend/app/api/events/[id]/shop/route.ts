import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/events/[id]/shop — list shop items for an event + player currency + purchases
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
    // Verify event is active
    const { rows: events } = await pool.query(
      `SELECT id, name, currency_name FROM seasonal_events
       WHERE id = $1 AND starts_at <= NOW() AND ends_at > NOW()`,
      [eventId],
    );
    if (events.length === 0) {
      return NextResponse.json({ error: 'Event not found or not active' }, { status: 404 });
    }

    const [items, currencyRows, purchasedRows] = await Promise.all([
      pool.query(
        `SELECT id, name, description, icon, currency_cost, max_per_player, sort_order
         FROM event_shop_items WHERE event_id = $1 ORDER BY sort_order ASC`,
        [eventId],
      ),
      pool.query(
        `SELECT amount FROM event_player_currency WHERE player_id = $1 AND event_id = $2`,
        [auth.playerId, eventId],
      ),
      pool.query(
        `SELECT item_id FROM event_player_purchases epp
         JOIN event_shop_items esi ON esi.id = epp.item_id
         WHERE epp.player_id = $1 AND esi.event_id = $2`,
        [auth.playerId, eventId],
      ),
    ]);

    const purchasedSet = new Set(purchasedRows.rows.map((r) => r.item_id));
    const playerCurrency = currencyRows.rows[0]?.amount ?? 0;

    return NextResponse.json({
      event: events[0],
      playerCurrency,
      items: items.rows.map((item) => ({
        ...item,
        purchased: purchasedSet.has(item.id),
      })),
    });
  } catch (err) {
    console.error('event shop GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch event shop' }, { status: 500 });
  }
}

// POST /api/events/[id]/shop — buy an item
// Body: { itemId: string }
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

  let body: { itemId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { itemId } = body;
  if (!itemId) return NextResponse.json({ error: 'itemId required' }, { status: 400 });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Verify event + item
    const { rows: items } = await client.query(
      `SELECT esi.id, esi.currency_cost, esi.max_per_player
       FROM event_shop_items esi
       JOIN seasonal_events se ON se.id = esi.event_id
       WHERE esi.id = $1 AND esi.event_id = $2
         AND se.starts_at <= NOW() AND se.ends_at > NOW()`,
      [itemId, eventId],
    );
    if (items.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json({ error: 'Item not found or event expired' }, { status: 404 });
    }

    const item = items[0];

    // Check max per player
    const { rows: existing } = await client.query(
      `SELECT COUNT(*) as cnt FROM event_player_purchases WHERE player_id = $1 AND item_id = $2`,
      [auth.playerId, itemId],
    );
    if (Number(existing[0].cnt) >= item.max_per_player) {
      await client.query('ROLLBACK');
      return NextResponse.json({ error: 'Purchase limit reached' }, { status: 409 });
    }

    // Check player currency
    const { rows: currencyRows } = await client.query(
      `SELECT amount FROM event_player_currency WHERE player_id = $1 AND event_id = $2`,
      [auth.playerId, eventId],
    );
    const currentCurrency = currencyRows[0]?.amount ?? 0;
    if (currentCurrency < item.currency_cost) {
      await client.query('ROLLBACK');
      return NextResponse.json({ error: 'Not enough event currency' }, { status: 400 });
    }

    // Deduct currency
    await client.query(
      `INSERT INTO event_player_currency (player_id, event_id, amount)
       VALUES ($1, $2, $3 - $4)
       ON CONFLICT (player_id, event_id) DO UPDATE SET amount = event_player_currency.amount - $4`,
      [auth.playerId, eventId, currentCurrency, item.currency_cost],
    );

    // Record purchase
    await client.query(
      `INSERT INTO event_player_purchases (player_id, item_id) VALUES ($1, $2)`,
      [auth.playerId, itemId],
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      itemId,
      remainingCurrency: currentCurrency - item.currency_cost,
    }, { status: 201 });
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('event shop POST error:', err);
    return NextResponse.json({ error: 'Failed to purchase item' }, { status: 500 });
  } finally {
    client.release();
  }
}
