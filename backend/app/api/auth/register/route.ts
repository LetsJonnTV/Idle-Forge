import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { supabase } from '@/lib/supabaseClient';
import { signJwt } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { optionsResponse, withCors } from '@/lib/cors';

export async function OPTIONS(request: NextRequest) {
  return optionsResponse(request.headers.get('origin'));
}

export async function POST(request: NextRequest) {
  const origin = request.headers.get('origin');
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) {
    return withCors(NextResponse.json({ error: 'Too many requests' }, { status: 429 }), origin);
  }

  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return withCors(NextResponse.json({ error: 'Invalid JSON' }, { status: 400 }), origin);
  }

  const { username, password } = body;

  if (!username || typeof username !== 'string' || username.trim().length < 3) {
    return withCors(NextResponse.json({ error: 'Username must be at least 3 characters' }, { status: 400 }), origin);
  }
  if (!password || typeof password !== 'string' || password.length < 6) {
    return withCors(NextResponse.json({ error: 'Password must be at least 6 characters' }, { status: 400 }), origin);
  }

  const cleanUsername = username.trim().toLowerCase();

  const { data: existing } = await supabase
    .from('players')
    .select('id')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (existing) {
    return withCors(NextResponse.json({ error: 'Username already taken' }, { status: 409 }), origin);
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const { data: player, error } = await supabase
    .from('players')
    .insert({ username: cleanUsername, password_hash: passwordHash })
    .select('id, username')
    .single();

  if (error || !player) {
    console.error('Register error:', error);
    return withCors(NextResponse.json({ error: 'Failed to create account' }, { status: 500 }), origin);
  }

  const token = signJwt({ playerId: player.id, username: player.username, isAdmin: false });

  return withCors(
    NextResponse.json({ token, playerId: player.id, username: player.username, isAdmin: false }, { status: 201 }),
    origin
  );
}
