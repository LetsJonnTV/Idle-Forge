import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// GET /api/clans/[id]/members — list clan members
export async function GET(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { data, error } = await db
    .from('clan_members')
    .select(
      'joined_at, player:player_id(id, username, total_strength, prestige_level, chapter)'
    )
    .eq('clan_id', params.id)
    .order('joined_at', { ascending: true });

  if (error) {
    console.error('Clan members error:', error);
    return NextResponse.json({ error: 'Failed to fetch members' }, { status: 500 });
  }

  return NextResponse.json({ members: data ?? [] });
}
