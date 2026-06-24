import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// DELETE /api/admin/events/[id]/items/[itemId] — remove a shop item
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; itemId: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { itemId } = await params;

  try {
    const { rowCount } = await pool.query(
      `DELETE FROM event_shop_items WHERE id = $1`,
      [itemId],
    );
    if (!rowCount) return NextResponse.json({ error: 'Item not found' }, { status: 404 });
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error('admin event item DELETE error:', err);
    return NextResponse.json({ error: 'Failed to delete item' }, { status: 500 });
  }
}

// PUT /api/admin/events/[id]/items/[itemId] — update a shop item
export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; itemId: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { itemId } = await params;

  let body: {
    name?: string;
    description?: string;
    currency_cost?: number;
    max_per_player?: number;
    sort_order?: number;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const fields: string[] = [];
  const values: unknown[] = [];

  if (body.name !== undefined) { values.push(body.name.trim()); fields.push(`name = $${values.length}`); }
  if (body.description !== undefined) { values.push(body.description); fields.push(`description = $${values.length}`); }
  if (body.currency_cost !== undefined) { values.push(body.currency_cost); fields.push(`currency_cost = $${values.length}`); }
  if (body.max_per_player !== undefined) { values.push(body.max_per_player); fields.push(`max_per_player = $${values.length}`); }
  if (body.sort_order !== undefined) { values.push(body.sort_order); fields.push(`sort_order = $${values.length}`); }

  if (fields.length === 0) return NextResponse.json({ error: 'Nothing to update' }, { status: 400 });

  values.push(itemId);
  try {
    const { rows } = await pool.query(
      `UPDATE event_shop_items SET ${fields.join(', ')} WHERE id = $${values.length} RETURNING *`,
      values,
    );
    if (rows.length === 0) return NextResponse.json({ error: 'Item not found' }, { status: 404 });
    return NextResponse.json({ item: rows[0] });
  } catch (err) {
    console.error('admin event item PUT error:', err);
    return NextResponse.json({ error: 'Failed to update item' }, { status: 500 });
  }
}
