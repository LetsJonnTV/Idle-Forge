import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

interface SavedItem {
  id: string;
  name: string;
  slot: string;
  tier: string;
  setId: string;
  power: number;
  iconPath: string;
}

// GET /api/players/[id]/profile — public profile with equipped items
export async function GET(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { data: player, error: playerError } = await db
    .from('players')
    .select('id, username, total_strength, prestige_level, chapter, clan_id')
    .eq('id', params.id)
    .maybeSingle();

  if (playerError || !player) {
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

  // Extract equipped items from game save
  let equippedItems: SavedItem[] = [];
  const { data: saveRow } = await db
    .from('game_saves')
    .select('save_data')
    .eq('player_id', params.id)
    .maybeSingle();

  if (saveRow?.save_data) {
    try {
      const saveData = saveRow.save_data as Record<string, unknown>;
      const inventory = (saveData['inventory'] as SavedItem[] | undefined) ?? [];
      const equippedBySlot = (saveData['equippedBySlot'] as Record<string, string> | undefined) ?? {};
      const equippedIds = new Set(Object.values(equippedBySlot));

      equippedItems = inventory
        .filter((item) => equippedIds.has(item.id))
        .map((item) => ({
          id: item.id,
          name: item.name,
          slot: item.slot,
          tier: item.tier,
          setId: item.setId,
          power: item.power,
          iconPath: item.iconPath,
        }));
    } catch {
      // ignore malformed save data
    }
  }

  return NextResponse.json({
    player: {
      id: player.id,
      username: player.username,
      total_strength: player.total_strength,
      prestige_level: player.prestige_level,
      chapter: player.chapter,
      clan_id: player.clan_id ?? null,
      clan_name: clanName,
    },
    equippedItems,
  });
}
