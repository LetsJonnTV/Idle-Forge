import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { supabase } from '@/lib/supabaseClient';
import { signJwt } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

export async function POST(request: NextRequest) {
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

  const { data: player, error } = await supabase
    .from('players')
    .select('id, username, password_hash')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (error || !player) {
    console.error('Login fetch error:', error);
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  const valid = await bcrypt.compare(password, player.password_hash);
  if (!valid) {
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  let isAdmin = false;
  let isBlocked = false;
  try {
    const { data: flags } = await supabase
      .from('players')
      .select('is_admin, is_blocked')
      .eq('id', player.id)
      .maybeSingle();
    isAdmin = flags?.is_admin ?? false;
    isBlocked = flags?.is_blocked ?? false;
  } catch {
    // columns don't exist yet — ignore
  }

  if (isBlocked) {
    return NextResponse.json({ error: 'Account blocked' }, { status: 403 });
  }

  const token = signJwt({ playerId: player.id, username: player.username, isAdmin });

  return NextResponse.json({ token, playerId: player.id, username: player.username, isAdmin });
}
