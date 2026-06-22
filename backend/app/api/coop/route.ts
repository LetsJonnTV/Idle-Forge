import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/coop — list active coop sessions waiting for a guest
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data, error } = await db
    .from('coop_sessions')
    .select(
      `id, status, boss_hp, created_at,
       host:host_id(id, username),
       guest:guest_id(id, username)`
    )
    .or(`host_id.eq.${auth.playerId},guest_id.eq.${auth.playerId}`)
    .in('status', ['waiting', 'active'])
    .order('created_at', { ascending: false })
    .limit(10);

  if (error) {
    console.error('Coop sessions error:', error);
    return NextResponse.json({ error: 'Failed to fetch sessions' }, { status: 500 });
  }

  return NextResponse.json({ sessions: data ?? [] });
}

// POST /api/coop — create a new coop session
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: session, error } = await db
    .from('coop_sessions')
    .insert({ host_id: auth.playerId, boss_hp: 1000, status: 'waiting' })
    .select()
    .single();

  if (error || !session) {
    console.error('Coop create error:', error);
    return NextResponse.json({ error: 'Failed to create session' }, { status: 500 });
  }

  return NextResponse.json({ session }, { status: 201 });
}
