import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// PATCH /api/players/me/password — change own password (JWT required)
export async function PATCH(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { currentPassword?: string; newPassword?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { currentPassword, newPassword } = body;
  if (!currentPassword || !newPassword) {
    return NextResponse.json({ error: 'currentPassword and newPassword required' }, { status: 400 });
  }
  if (newPassword.length < 6) {
    return NextResponse.json({ error: 'New password must be at least 6 characters' }, { status: 400 });
  }

  const { data: player, error } = await db
    .from('players')
    .select('password_hash')
    .eq('id', auth.playerId)
    .single();

  if (error || !player) {
    return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  }

  const valid = await bcrypt.compare(currentPassword, player.password_hash);
  if (!valid) {
    return NextResponse.json({ error: 'Current password is incorrect' }, { status: 401 });
  }

  const newHash = await bcrypt.hash(newPassword, 12);
  const { error: updateError } = await db
    .from('players')
    .update({ password_hash: newHash })
    .eq('id', auth.playerId);

  if (updateError) {
    console.error('Password update error:', updateError);
    return NextResponse.json({ error: 'Failed to update password' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
