import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/clans/[id]/chat — returns last 50 messages ordered by created_at ASC
export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { id: clanId } = params;

  const { data, error } = await db
    .from('clan_chat')
    .select('id, player_id, username, message, created_at')
    .eq('clan_id', clanId)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) {
    console.error('Clan chat GET error:', error);
    return NextResponse.json({ error: 'Failed to fetch messages' }, { status: 500 });
  }

  // Return in ascending order (oldest first)
  const messages = (data ?? []).reverse();
  return NextResponse.json({ messages });
}

// POST /api/clans/[id]/chat — send a message (JWT required, must be clan member)
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { id: clanId } = params;

  let body: { message?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { message } = body;
  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    return NextResponse.json({ error: 'Message cannot be empty' }, { status: 400 });
  }
  if (message.trim().length > 500) {
    return NextResponse.json({ error: 'Message too long (max 500 characters)' }, { status: 400 });
  }

  // Check that the player is a member of this clan
  const { data: membership } = await db
    .from('clan_members')
    .select('player_id')
    .eq('clan_id', clanId)
    .eq('player_id', auth.playerId)
    .maybeSingle();

  if (!membership) {
    return NextResponse.json({ error: 'Not a member of this clan' }, { status: 403 });
  }

  // Fetch username
  const { data: player } = await db
    .from('players')
    .select('username')
    .eq('id', auth.playerId)
    .single();

  if (!player) {
    return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  }

  const { data: chatMessage, error: insertError } = await db
    .from('clan_chat')
    .insert({
      clan_id: clanId,
      player_id: auth.playerId,
      username: player.username,
      message: message.trim(),
    })
    .select('id, player_id, username, message, created_at')
    .single();

  if (insertError || !chatMessage) {
    console.error('Clan chat POST error:', insertError);
    return NextResponse.json({ error: 'Failed to send message' }, { status: 500 });
  }

  return NextResponse.json({ message: chatMessage }, { status: 201 });
}
