import { NextRequest, NextResponse } from 'next/server';
import bcrypt from 'bcryptjs';
import { db } from '@/lib/dbClient';
import { signJwt } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { logger } from '@/lib/logger';

export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  logger.info('register', `POST /api/auth/register from IP ${ip}`);

  const { allowed } = checkRateLimit(ip);
  if (!allowed) {
    logger.warn('register', `Rate limit exceeded for IP ${ip}`);
    return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
  }

  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    logger.warn('register', 'Invalid JSON body');
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { username, password } = body;

  if (!username || typeof username !== 'string' || username.trim().length < 3) {
    logger.warn('register', `Invalid username: "${username}"`);
    return NextResponse.json({ error: 'Username must be at least 3 characters' }, { status: 400 });
  }
  if (!password || typeof password !== 'string' || password.length < 6) {
    logger.warn('register', 'Password too short');
    return NextResponse.json({ error: 'Password must be at least 6 characters' }, { status: 400 });
  }

  const cleanUsername = username.trim().toLowerCase();
  logger.debug('register', `Checking availability for username: ${cleanUsername}`);

  const { data: existing, error: existingError } = await db
    .from('players')
    .select('id')
    .eq('username', cleanUsername)
    .maybeSingle();

  if (existingError) {
    logger.error('register', `Failed to check username availability for "${cleanUsername}"`, existingError);
    return NextResponse.json({ error: 'Registration temporarily unavailable' }, { status: 500 });
  }

  if (existing) {
    logger.warn('register', `Username already taken: ${cleanUsername}`);
    return NextResponse.json({ error: 'Username already taken' }, { status: 409 });
  }

  const passwordHash = await bcrypt.hash(password, 12);

  const { data: player, error } = await db
    .from('players')
    .insert({ username: cleanUsername, password_hash: passwordHash })
    .select('id, username')
    .single();

  if (error || !player) {
    const isUniqueViolation =
      error?.code === '23505' ||
      (typeof error?.message === 'string' &&
        error.message.toLowerCase().includes('duplicate key'));
    if (isUniqueViolation) {
      logger.warn('register', `Username already taken (race): ${cleanUsername}`);
      return NextResponse.json({ error: 'Username already taken' }, { status: 409 });
    }

    logger.error('register', `Failed to create account for "${cleanUsername}"`, error);
    return NextResponse.json({ error: 'Failed to create account' }, { status: 500 });
  }

  let token: string;
  try {
    token = signJwt({ playerId: player.id, username: player.username, isAdmin: false });
  } catch (e) {
    logger.error('register', 'JWT signing failed', e);
    return NextResponse.json({ error: 'Authentication temporarily unavailable' }, { status: 500 });
  }
  logger.info('register', `Account created successfully: ${cleanUsername} (id: ${player.id})`);

  return NextResponse.json({ token, playerId: player.id, username: player.username, isAdmin: false }, { status: 201 });
}

