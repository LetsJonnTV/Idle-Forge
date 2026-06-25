import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// POST /api/clans/[id]/join — join a clan (JWT required)
export async function POST(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  // Check clan exists
  const { data: clan } = await db
    .from('clans')
    .select('id, name')
    .eq('id', params.id)
    .maybeSingle();

  if (!clan) return NextResponse.json({ error: 'Clan not found' }, { status: 404 });

  // Check if already a member
  const { data: existing } = await db
    .from('clan_members')
    .select('clan_id')
    .eq('clan_id', params.id)
    .eq('player_id', auth.playerId)
    .maybeSingle();

  if (existing) {
    return NextResponse.json({ error: 'Already a member of this clan' }, { status: 409 });
  }

  // Remove from any previous clan
  const { data: player } = await db
    .from('players')
    .select('clan_id')
    .eq('id', auth.playerId)
    .maybeSingle();

  if (player?.clan_id) {
    await db
      .from('clan_members')
      .delete()
      .eq('clan_id', player.clan_id)
      .eq('player_id', auth.playerId);
  }

  // Join new clan
  const { error: memberError } = await db
    .from('clan_members')
    .insert({ clan_id: params.id, player_id: auth.playerId });

  if (memberError) {
    console.error('Join clan member insert error:', memberError);
    return NextResponse.json({ error: 'Failed to join clan' }, { status: 500 });
  }

  const { error: playerError } = await db
    .from('players')
    .update({ clan_id: params.id })
    .eq('id', auth.playerId);

  if (playerError) {
    console.error('Join clan player update error:', playerError);
    return NextResponse.json({ error: 'Failed to update player clan' }, { status: 500 });
  }

  return NextResponse.json({ message: `Joined clan ${clan.name}`, clanId: clan.id });
}
