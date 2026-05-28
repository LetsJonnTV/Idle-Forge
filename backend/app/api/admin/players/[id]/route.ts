import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { supabase } from '@/lib/supabaseClient';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// POST /api/admin/players/[id]/reset-password
export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  let body: { newPassword?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { newPassword } = body;
  if (!newPassword || newPassword.length < 6) {
    return NextResponse.json({ error: 'newPassword must be at least 6 characters' }, { status: 400 });
  }

  const hash = await bcrypt.hash(newPassword, 12);
  const { error } = await supabase
    .from('players')
    .update({ password_hash: hash })
    .eq('id', params.id);

  if (error) {
    console.error('Admin reset-password error:', error);
    return NextResponse.json({ error: 'Failed to reset password' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}

// PATCH /api/admin/players/[id]/status — block or unblock
export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  let body: { blocked?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (typeof body.blocked !== 'boolean') {
    return NextResponse.json({ error: 'blocked (boolean) required' }, { status: 400 });
  }

  const { error } = await supabase
    .from('players')
    .update({ is_blocked: body.blocked })
    .eq('id', params.id);

  if (error) {
    console.error('Admin status update error:', error);
    return NextResponse.json({ error: 'Failed to update status' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}

// DELETE /api/admin/players/[id] — delete player
export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  const { error } = await supabase
    .from('players')
    .delete()
    .eq('id', params.id);

  if (error) {
    console.error('Admin delete player error:', error);
    return NextResponse.json({ error: 'Failed to delete player' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}

// POST /api/admin/players/[id]/give — give gold or item
export async function PUT(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  let body: { type?: string; amount?: number; itemId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (!body.type || !['gold', 'item'].includes(body.type)) {
    return NextResponse.json({ error: 'type must be gold or item' }, { status: 400 });
  }
  if (body.type === 'gold' && (!body.amount || body.amount <= 0)) {
    return NextResponse.json({ error: 'amount required for gold' }, { status: 400 });
  }
  if (body.type === 'item' && !body.itemId) {
    return NextResponse.json({ error: 'itemId required for item' }, { status: 400 });
  }

  const { error } = await supabase.from('pending_rewards').insert({
    player_id: params.id,
    reward_type: body.type,
    amount: body.type === 'gold' ? body.amount : null,
    item_id: body.type === 'item' ? body.itemId : null,
    given_by: auth.playerId,
  });

  if (error) {
    console.error('Admin give reward error:', error);
    return NextResponse.json({ error: 'Failed to give reward' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
