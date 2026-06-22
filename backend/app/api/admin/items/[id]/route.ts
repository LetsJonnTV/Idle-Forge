import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { requireAdmin } from '@/lib/adminAuth';

// PATCH /api/admin/items/[id] — admin only, update an item blueprint
export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  let body: { name?: string; slot?: string; base_power?: number; icon_path?: string; is_active?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const updates: Record<string, unknown> = {};
  if (body.name !== undefined) updates['name'] = body.name;
  if (body.slot !== undefined) updates['slot'] = body.slot;
  if (body.base_power !== undefined) updates['base_power'] = body.base_power;
  if (body.icon_path !== undefined) updates['icon_path'] = body.icon_path;
  if (body.is_active !== undefined) updates['is_active'] = body.is_active;

  if (Object.keys(updates).length === 0) {
    return NextResponse.json({ error: 'No fields to update' }, { status: 400 });
  }

  const { data: item, error } = await db
    .from('item_blueprints')
    .update(updates)
    .eq('id', params.id)
    .select()
    .single();

  if (error) {
    console.error('Admin update item error:', error);
    return NextResponse.json({ error: 'Failed to update item' }, { status: 500 });
  }

  return NextResponse.json({ item });
}

// DELETE /api/admin/items/[id] — admin only, deactivate (soft delete) an item
export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  const { error } = await db
    .from('item_blueprints')
    .update({ is_active: false })
    .eq('id', params.id);

  if (error) {
    console.error('Admin delete item error:', error);
    return NextResponse.json({ error: 'Failed to deactivate item' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
