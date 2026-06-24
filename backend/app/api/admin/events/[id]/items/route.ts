import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/admin/events/[id]/items — list shop items for event with purchase counts
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { id: eventId } = await params;

  try {
    const { rows } = await pool.query(
      `SELECT
         esi.id, esi.name, esi.description, esi.icon,
         esi.currency_cost, esi.max_per_player, esi.sort_order,
         COUNT(epp.player_id)::int AS purchase_count
       FROM event_shop_items esi
       LEFT JOIN event_player_purchases epp ON epp.item_id = esi.id
       WHERE esi.event_id = $1
       GROUP BY esi.id
       ORDER BY esi.sort_order ASC, esi.name ASC`,
      [eventId],
    );
    return NextResponse.json({ items: rows });
  } catch (err) {
    console.error('admin event items GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch items' }, { status: 500 });
  }
}

// POST /api/admin/events/[id]/items — add a shop item to the event
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

  let body: {
    name?: string;
    description?: string;
    icon?: string;
    currency_cost?: number;
    max_per_player?: number;
    sort_order?: number;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const {
    name,
    description = '',
    icon = 'event',
    currency_cost,
    max_per_player = 1,
    sort_order = 0,
  } = body;

  if (!name?.trim()) return NextResponse.json({ error: 'name is required' }, { status: 400 });
  if (!currency_cost || currency_cost <= 0) {
    return NextResponse.json({ error: 'currency_cost must be > 0' }, { status: 400 });
  }

  // Verify event exists
  const { rows: events } = await pool.query(
    `SELECT id FROM seasonal_events WHERE id = $1`,
    [eventId],
  );
  if (events.length === 0) return NextResponse.json({ error: 'Event not found' }, { status: 404 });

  try {
    const { rows } = await pool.query(
      `INSERT INTO event_shop_items (event_id, name, description, icon, currency_cost, max_per_player, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [eventId, name.trim(), description, icon, currency_cost, max_per_player, sort_order],
    );
    return NextResponse.json({ item: rows[0] }, { status: 201 });
  } catch (err) {
    console.error('admin event items POST error:', err);
    return NextResponse.json({ error: 'Failed to create item' }, { status: 500 });
  }
}
