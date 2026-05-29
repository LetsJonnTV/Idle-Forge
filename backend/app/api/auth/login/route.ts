import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { supabase } from '@/lib/supabaseClient';
import { signJwt } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { logger } from '@/lib/logger';

export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  logger.info('login', `POST /api/auth/login from IP ${ip}`);

  const { allowed } = checkRateLimit(ip);
  if (!allowed) {
    logger.warn('login', `Rate limit exceeded for IP ${ip}`);
    return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
  }

  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    logger.warn('login', 'Invalid JSON body');
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { username, password } = body;

  if (!username || !password) {
    logger.warn('login', 'Missing username or password');
    return NextResponse.json({ error: 'Username and password required' }, { status: 400 });
  }

  const cleanUsername = username.trim().toLowerCase();
  logger.debug('login', `Attempting login for username: ${cleanUsername}`);

  const { data: player, error } = await supabase
    .from('players')
    .select('id, username, password_hash')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (error) {
    logger.error('login', `Supabase error fetching player "${cleanUsername}"`, error);
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }
  if (!player) {
    logger.warn('login', `No player found for username: ${cleanUsername}`);
    return NextResponse.json({ error: 'Invalid credentials' }, { status: 401 });
  }

  logger.debug('login', `Player found: ${player.id}, verifying password`);
  const valid = await bcrypt.compare(password, player.password_hash);
  if (!valid) {
    logger.warn('login', `Wrong password for username: ${cleanUsername}`);
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
    logger.debug('login', `Flags for ${cleanUsername}: isAdmin=${isAdmin}, isBlocked=${isBlocked}`);
  } catch (e) {
    logger.warn('login', 'Could not fetch is_admin/is_blocked flags (columns may not exist)', e);
  }

  if (isBlocked) {
    logger.warn('login', `Blocked account attempted login: ${cleanUsername}`);
    return NextResponse.json({ error: 'Account blocked' }, { status: 403 });
  }

  const token = signJwt({ playerId: player.id, username: player.username, isAdmin });
  logger.info('login', `Login successful for ${cleanUsername} (id: ${player.id})`);

  return NextResponse.json({ token, playerId: player.id, username: player.username, isAdmin });
}

