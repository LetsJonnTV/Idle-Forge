import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// PUT /api/admin/events/[id] — update event (name, description, dates, end early)
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { id } = await params;

  let body: {
    name?: string; description?: string; starts_at?: string; ends_at?: string;
    currency_name?: string; banner_color?: string; end_now?: boolean;
    event_type?: string; type_config?: object; notify_on_start?: boolean;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const VALID_TYPES = ['collection','world_boss','forge_tournament','dungeon_rush','trade_expedition'];
  const fields: string[] = [];
  const values: unknown[] = [];

  if (body.name !== undefined) { values.push(body.name.trim()); fields.push(`name = $${values.length}`); }
  if (body.description !== undefined) { values.push(body.description); fields.push(`description = $${values.length}`); }
  if (body.currency_name !== undefined) { values.push(body.currency_name); fields.push(`currency_name = $${values.length}`); }
  if (body.banner_color !== undefined) { values.push(body.banner_color); fields.push(`banner_color = $${values.length}`); }
  if (body.event_type !== undefined) {
    if (!VALID_TYPES.includes(body.event_type)) return NextResponse.json({ error: 'Invalid event_type' }, { status: 400 });
    values.push(body.event_type); fields.push(`event_type = $${values.length}`);
  }
  if (body.type_config !== undefined) { values.push(JSON.stringify(body.type_config)); fields.push(`type_config = $${values.length}`); }
  if (body.notify_on_start !== undefined) { values.push(body.notify_on_start); fields.push(`notify_on_start = $${values.length}`); }
  if (body.starts_at !== undefined) { values.push(new Date(body.starts_at).toISOString()); fields.push(`starts_at = $${values.length}`); }
  if (body.end_now) {
    values.push(new Date().toISOString());
    fields.push(`ends_at = $${values.length}`);
  } else if (body.ends_at !== undefined) {
    values.push(new Date(body.ends_at).toISOString());
    fields.push(`ends_at = $${values.length}`);
  }

  if (fields.length === 0) {
    return NextResponse.json({ error: 'Nothing to update' }, { status: 400 });
  }

  values.push(id);
  try {
    const { rows } = await pool.query(
      `UPDATE seasonal_events SET ${fields.join(', ')} WHERE id = $${values.length} RETURNING *`,
      values,
    );
    if (rows.length === 0) return NextResponse.json({ error: 'Event not found' }, { status: 404 });
    return NextResponse.json({ event: rows[0] });
  } catch (err) {
    console.error('admin events PUT error:', err);
    return NextResponse.json({ error: 'Failed to update event' }, { status: 500 });
  }
}

// DELETE /api/admin/events/[id] — delete event (cascades to items and player data)
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { id } = await params;

  try {
    const { rowCount } = await pool.query(
      `DELETE FROM seasonal_events WHERE id = $1`,
      [id],
    );
    if (!rowCount) return NextResponse.json({ error: 'Event not found' }, { status: 404 });
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error('admin events DELETE error:', err);
    return NextResponse.json({ error: 'Failed to delete event' }, { status: 500 });
  }
}
