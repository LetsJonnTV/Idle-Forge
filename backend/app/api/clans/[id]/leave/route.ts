import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// POST /api/clans/[id]/leave — leave a clan (JWT required)
// If player is leader and clan has other members, transfer leadership to next member
// If player is leader and solo, delete the clan
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

  // Verify membership
  const { data: membership } = await db
    .from('clan_members')
    .select('player_id')
    .eq('clan_id', clanId)
    .eq('player_id', auth.playerId)
    .maybeSingle();

  if (!membership) {
    return NextResponse.json({ error: 'Not a member of this clan' }, { status: 400 });
  }

  // Fetch clan to check leadership
  const { data: clan } = await db
    .from('clans')
    .select('id, leader_id')
    .eq('id', clanId)
    .single();

  if (!clan) {
    return NextResponse.json({ error: 'Clan not found' }, { status: 404 });
  }

  const isLeader = clan.leader_id === auth.playerId;

  if (isLeader) {
    // Fetch other members
    const { data: otherMembers } = await db
      .from('clan_members')
      .select('player_id, joined_at')
      .eq('clan_id', clanId)
      .neq('player_id', auth.playerId)
      .order('joined_at', { ascending: true })
      .limit(1);

    if (!otherMembers || otherMembers.length === 0) {
      // No other members — delete the clan entirely
      await db.from('players').update({ clan_id: null }).eq('id', auth.playerId);
      await db.from('clans').delete().eq('id', clanId);
      return NextResponse.json({ message: 'Clan deleted' });
    }

    // Transfer leadership to oldest remaining member
    const newLeaderId = otherMembers[0].player_id;
    await db
      .from('clans')
      .update({ leader_id: newLeaderId })
      .eq('id', clanId);
  }

  // Remove player from clan_members
  await db
    .from('clan_members')
    .delete()
    .eq('clan_id', clanId)
    .eq('player_id', auth.playerId);

  // Clear player's clan_id
  await db
    .from('players')
    .update({ clan_id: null })
    .eq('id', auth.playerId);

  return NextResponse.json({ message: 'Left clan successfully' });
}
