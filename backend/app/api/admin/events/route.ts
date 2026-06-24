import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/admin/events — list all events (past, active, upcoming)
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  try {
    const { rows } = await pool.query(
      `SELECT
         e.id, e.name, e.description, e.starts_at, e.ends_at,
         e.currency_name, e.banner_color, e.created_at,
         e.event_type, e.type_config, e.notify_on_start,
         COUNT(esi.id)::int AS item_count,
         COALESCE(SUM(epc.amount), 0)::bigint AS total_currency_distributed
       FROM seasonal_events e
       LEFT JOIN event_shop_items esi ON esi.event_id = e.id
       LEFT JOIN event_player_currency epc ON epc.event_id = e.id
       GROUP BY e.id
       ORDER BY e.starts_at DESC`,
    );

    const now = new Date();
    const events = rows.map((e) => ({
      ...e,
      status:
        new Date(e.ends_at) < now
          ? 'expired'
          : new Date(e.starts_at) > now
            ? 'upcoming'
            : 'active',
    }));

    return NextResponse.json({ events });
  } catch (err) {
    console.error('admin events GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch events' }, { status: 500 });
  }
}

// POST /api/admin/events — create a new event
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const VALID_TYPES = ['collection','world_boss','forge_tournament','dungeon_rush','trade_expedition'];

  let body: {
    name?: string; description?: string; starts_at?: string; ends_at?: string;
    currency_name?: string; banner_color?: string;
    event_type?: string; type_config?: object; notify_on_start?: boolean;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const {
    name, description = '', starts_at, ends_at,
    currency_name = 'Event-Münzen', banner_color = '#D4A84B',
    event_type = 'collection', type_config = {}, notify_on_start = false,
  } = body;

  if (!name?.trim()) return NextResponse.json({ error: 'name is required' }, { status: 400 });
  if (!starts_at) return NextResponse.json({ error: 'starts_at is required' }, { status: 400 });
  if (!ends_at) return NextResponse.json({ error: 'ends_at is required' }, { status: 400 });
  if (!VALID_TYPES.includes(event_type)) return NextResponse.json({ error: `event_type must be one of: ${VALID_TYPES.join(', ')}` }, { status: 400 });

  const start = new Date(starts_at);
  const end = new Date(ends_at);
  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    return NextResponse.json({ error: 'Invalid date format' }, { status: 400 });
  }
  if (end <= start) {
    return NextResponse.json({ error: 'ends_at must be after starts_at' }, { status: 400 });
  }

  try {
    const { rows } = await pool.query(
      `INSERT INTO seasonal_events (name, description, starts_at, ends_at, currency_name, banner_color, event_type, type_config, notify_on_start)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [name.trim(), description, start.toISOString(), end.toISOString(), currency_name, banner_color, event_type, JSON.stringify(type_config), notify_on_start],
    );
    return NextResponse.json({ event: rows[0] }, { status: 201 });
  } catch (err) {
    console.error('admin events POST error:', err);
    return NextResponse.json({ error: 'Failed to create event' }, { status: 500 });
  }
}
