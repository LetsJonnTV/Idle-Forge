import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/friends — list accepted friends for the authenticated player
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data, error } = await db
    .from('friends')
    .select(
      `id, status, created_at,
       requester:requester_id(id, username, total_strength, prestige_level),
       addressee:addressee_id(id, username, total_strength, prestige_level)`
    )
    .or(`requester_id.eq.${auth.playerId},addressee_id.eq.${auth.playerId}`)
    .in('status', ['accepted', 'pending']);

  if (error) {
    console.error('Friends list error:', error);
    return NextResponse.json({ error: 'Failed to fetch friends' }, { status: 500 });
  }

  return NextResponse.json({ friends: data ?? [] });
}

// POST /api/friends — send a friend request by target username
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { targetUsername?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { targetUsername } = body;
  if (!targetUsername) {
    return NextResponse.json({ error: 'targetUsername is required' }, { status: 400 });
  }

  // Resolve target player
  const { data: target, error: targetError } = await db
    .from('players')
    .select('id, username')
    .eq('username', targetUsername.trim().toLowerCase())
    .maybeSingle();

  if (targetError || !target) {
    return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  }

  if (target.id === auth.playerId) {
    return NextResponse.json({ error: 'Cannot add yourself' }, { status: 400 });
  }

  // Check for existing relationship
  const { data: existing } = await db
    .from('friends')
    .select('id, status')
    .or(
      `and(requester_id.eq.${auth.playerId},addressee_id.eq.${target.id}),` +
      `and(requester_id.eq.${target.id},addressee_id.eq.${auth.playerId})`
    )
    .maybeSingle();

  if (existing) {
    return NextResponse.json(
      { error: `Relationship already exists: ${existing.status}` },
      { status: 409 }
    );
  }

  const { data: request_, error: insertError } = await db
    .from('friends')
    .insert({ requester_id: auth.playerId, addressee_id: target.id })
    .select()
    .single();

  if (insertError || !request_) {
    console.error('Friend request error:', insertError);
    return NextResponse.json({ error: 'Failed to send request' }, { status: 500 });
  }

  return NextResponse.json({ friendRequest: request_ }, { status: 201 });
}
