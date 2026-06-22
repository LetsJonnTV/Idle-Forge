import { NextRequest, NextResponse } from 'next/server';
import { OAuth2Client } from 'google-auth-library';
import { supabase } from '@/lib/supabaseClient';
import { signJwt } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { logger } from '@/lib/logger';

const oauth2Client = new OAuth2Client(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
);

export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  logger.info('google-auth', `POST /api/auth/google from IP ${ip}`);

  const { allowed } = checkRateLimit(ip);
  if (!allowed) {
    logger.warn('google-auth', `Rate limit exceeded for IP ${ip}`);
    return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
  }

  let body: { idToken?: string };
  try {
    body = await request.json();
  } catch {
    logger.warn('google-auth', 'Invalid JSON body');
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { idToken } = body;
  if (!idToken) {
    logger.warn('google-auth', 'Missing idToken');
    return NextResponse.json({ error: 'idToken required' }, { status: 400 });
  }

  try {
    // Verify ID Token with Google
    const ticket = await oauth2Client.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload) {
      logger.warn('google-auth', 'No payload in ID token');
      return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
    }

    const { email, name, sub: googleId } = payload;

    if (!email || !googleId) {
      logger.warn('google-auth', 'Missing email or googleId in payload');
      return NextResponse.json({ error: 'Invalid token payload' }, { status: 401 });
    }

    logger.debug('google-auth', `Verified Google ID: ${googleId}, email: ${email}`);

    // Check if player already exists
    let player = await supabase
      .from('players')
      .select('id, username, email')
      .eq('google_id', googleId)
      .maybeSingle();

    if (player.error && player.error.code !== 'PGRST116') {
      logger.error('google-auth', `Supabase error looking up googleId: ${googleId}`, player.error);
      return NextResponse.json({ error: 'Database error' }, { status: 500 });
    }

    // If player exists, return token
    if (player.data) {
      logger.info('google-auth', `Existing player logged in: ${player.data.id}`);
      const token = signJwt({
        playerId: player.data.id,
        username: player.data.username,
        isAdmin: false,
      });
      return NextResponse.json({
        token,
        playerId: player.data.id,
        username: player.data.username,
        isNewPlayer: false,
      });
    }

    // Create new player with Google ID
    const username = email.split('@')[0];
    const newPlayer = await supabase
      .from('players')
      .insert({
        username,
        email,
        google_id: googleId,
        password_hash: '', // No password for OAuth players
        created_at: new Date().toISOString(),
      })
      .select('id, username')
      .single();

    if (newPlayer.error) {
      logger.error('google-auth', `Failed to create player for ${email}`, newPlayer.error);
      // Check if username already taken, try with suffix
      const uniqueUsername = `${username}_${Math.random().toString(36).substring(7)}`;
      const retryPlayer = await supabase
        .from('players')
        .insert({
          username: uniqueUsername,
          email,
          google_id: googleId,
          password_hash: '',
          created_at: new Date().toISOString(),
        })
        .select('id, username')
        .single();

      if (retryPlayer.error) {
        logger.error('google-auth', `Failed to create player with unique username`, retryPlayer.error);
        return NextResponse.json({ error: 'Failed to create account' }, { status: 500 });
      }

      const token = signJwt({
        playerId: retryPlayer.data.id,
        username: retryPlayer.data.username,
        isAdmin: false,
      });

      logger.info('google-auth', `New player created: ${retryPlayer.data.id}`);
      return NextResponse.json({
        token,
        playerId: retryPlayer.data.id,
        username: retryPlayer.data.username,
        isNewPlayer: true,
      });
    }

    const token = signJwt({
      playerId: newPlayer.data.id,
      username: newPlayer.data.username,
      isAdmin: false,
    });

    logger.info('google-auth', `New player created: ${newPlayer.data.id}`);
    return NextResponse.json({
      token,
      playerId: newPlayer.data.id,
      username: newPlayer.data.username,
      isNewPlayer: true,
    });
  } catch (error) {
    logger.error('google-auth', `OAuth verification failed`, error);
    return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
  }
}
