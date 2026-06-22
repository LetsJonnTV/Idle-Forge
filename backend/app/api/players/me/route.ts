import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/players/me — get current player's profile (JWT required)
// Returns: { player: { id, username, clan_id, clan_name? } }
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: player, error } = await db
    .from('players')
    .select('id, username, clan_id, total_strength, prestige_level, chapter')
    .eq('id', auth.playerId)
    .single();

  if (error || !player) {
    console.error('Get player profile error:', error);
    return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  }

  let clanName: string | null = null;
  if (player.clan_id) {
    const { data: clan } = await db
      .from('clans')
      .select('name')
      .eq('id', player.clan_id)
      .single();
    clanName = clan?.name ?? null;
  }

  return NextResponse.json({
    player: {
      id: player.id,
      username: player.username,
      clan_id: player.clan_id ?? null,
      clan_name: clanName,
      total_strength: player.total_strength,
      prestige_level: player.prestige_level,
      chapter: player.chapter,
    },
  });
}
