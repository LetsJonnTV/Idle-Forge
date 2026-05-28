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

  // Validate inputs
  if (!username || typeof username !== 'string' || username.trim().length < 3) {
    return NextResponse.json(
      { error: 'Username must be at least 3 characters' },
      { status: 400 }
    );
  }
  if (!password || typeof password !== 'string' || password.length < 6) {
    return NextResponse.json(
      { error: 'Password must be at least 6 characters' },
      { status: 400 }
    );
  }

  const cleanUsername = username.trim().toLowerCase();

  // Check if username already taken
  const { data: existing } = await supabase
    .from('players')
    .select('id')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (existing) {
    return NextResponse.json({ error: 'Username already taken' }, { status: 409 });
  }

  // Hash password
  const passwordHash = await bcrypt.hash(password, 12);

  // Create player
  const { data: player, error } = await supabase
    .from('players')
    .insert({ username: cleanUsername, password_hash: passwordHash })
    .select('id, username')
    .single();

  if (error || !player) {
    console.error('Register error:', error);
    return NextResponse.json({ error: 'Failed to create account' }, { status: 500 });
  }

  const token = signJwt({ playerId: player.id, username: player.username, isAdmin: false });

  return NextResponse.json(
    { token, playerId: player.id, username: player.username, isAdmin: false },
    { status: 201 }
  );
}
