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
  // Rate limit
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) {
    return withCors(NextResponse.json({ error: 'Too many requests' }, { status: 429 }), request.headers.get('origin'));
  }

  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return withCors(NextResponse.json({ error: 'Invalid JSON' }, { status: 400 }), request.headers.get('origin'));
  }

  const { username, password } = body;

  if (!username || !password) {
    return withCors(NextResponse.json({ error: 'Username and password required' }, { status: 400 }), request.headers.get('origin'));
  }

  const cleanUsername = username.trim().toLowerCase();

  // Fetch player — only core columns first (resilient to missing is_admin/is_blocked)
  const { data: player, error } = await supabase
    .from('players')
    .select('id, username, password_hash')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (error || !player) {
    console.error('Login fetch error:', error);
    return withCors(NextResponse.json({ error: 'Invalid credentials' }, { status: 401 }), request.headers.get('origin'));
  }

  // Verify password — constant-time comparison
  const valid = await bcrypt.compare(password, player.password_hash);
  if (!valid) {
    return withCors(NextResponse.json({ error: 'Invalid credentials' }, { status: 401 }), request.headers.get('origin'));
  }

  // Fetch admin/blocked flags separately (columns may not exist yet in older DB)
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
    return withCors(NextResponse.json({ error: 'Account blocked' }, { status: 403 }), request.headers.get('origin'));
  }

  const token = signJwt({ playerId: player.id, username: player.username, isAdmin });

  return withCors(
    NextResponse.json({ token, playerId: player.id, username: player.username, isAdmin }),
    request.headers.get('origin')
  );
}
