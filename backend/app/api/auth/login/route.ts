import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { supabase } from '@/lib/supabaseClient';
import { signJwt } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

export async function POST(request: NextRequest) {
  // Rate limit
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) {
    return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
  }

  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { username, password } = body;

  if (!username || !password) {
    return NextResponse.json({ error: 'Username and password required' }, { status: 400 });
  }

  const cleanUsername = username.trim().toLowerCase();

  // Fetch player
  const { data: player, error } = await supabase
    .from('players')
    .select('id, username, password_hash, is_admin, is_blocked')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (error || !player) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  if (player.is_blocked) {
    return NextResponse.json({ error: 'Account blocked' }, { status: 403 });
  }

  // Verify password — constant-time comparison
  const valid = await bcrypt.compare(password, player.password_hash);
  if (!valid) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  const token = signJwt({ playerId: player.id, username: player.username, isAdmin: player.is_admin ?? false });

  return NextResponse.json({ token, playerId: player.id, username: player.username, isAdmin: player.is_admin ?? false });
}
