import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const VALID_SLOTS = new Set(['weapon', 'armor', 'helm', 'gloves', 'boots', 'ring']);
const VALID_TIERS = new Set(['common', 'uncommon', 'rare', 'epic', 'legendary']);

// GET /api/players/me/inventory — returns all items for the authenticated player
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: rows, error } = await db
    .from('player_items')
    .select('id, slot, tier, set_id, power, sell_value, name, icon_path, is_locked, is_equipped, enchantments, updated_at')
    .eq('player_id', auth.playerId)
    .order('updated_at', { ascending: true });

  if (error) {
    console.error('Fetch inventory error:', error);
    return NextResponse.json({ error: 'Failed to fetch inventory' }, { status: 500 });
  }

  // Return camelCase keys so GameItem.fromJson() works without remapping
  const items = (rows ?? []).map((r: Record<string, unknown>) => ({
    id: r.id,
    name: r.name,
    slot: r.slot,
    tier: r.tier,
    setId: r.set_id,
    power: r.power,
    sellValue: r.sell_value,
    iconPath: r.icon_path,
    isLocked: r.is_locked,
    isEquipped: r.is_equipped,
    enchantments: r.enchantments,
    updatedAt: r.updated_at,
  }));

  return NextResponse.json({ items });
}

interface ItemPayload {
  id: string;
  slot: string;
  tier: string;
  setId: string;
  power: number;
  sellValue: number;
  name: string;
  iconPath: string;
  isLocked: boolean;
  enchantments: unknown[];
}

// PUT /api/players/me/inventory — bulk-replace all items for the authenticated player
// Called by the app on pause/close to sync the full inventory to the server.
export async function PUT(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { items?: unknown; equippedBySlot?: Record<string, string> };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (!Array.isArray(body.items)) {
    return NextResponse.json({ error: 'items must be an array' }, { status: 400 });
  }

  const equippedIds = new Set(Object.values(body.equippedBySlot ?? {}));

  const rows: Record<string, unknown>[] = [];
  for (const raw of body.items as ItemPayload[]) {
    if (typeof raw.id !== 'string' || !raw.id) continue;
    if (!VALID_SLOTS.has(raw.slot)) continue;
    rows.push({
      id: raw.id,
      player_id: auth.playerId,
      slot: raw.slot,
      tier: VALID_TIERS.has(raw.tier) ? raw.tier : 'common',
      set_id: typeof raw.setId === 'string' ? raw.setId : 'ember',
      power: Math.floor(Number(raw.power) || 0),
      sell_value: Math.floor(Number(raw.sellValue) || 0),
      name: typeof raw.name === 'string' ? raw.name : '',
      icon_path: typeof raw.iconPath === 'string' ? raw.iconPath : '',
      is_locked: raw.isLocked === true,
      is_equipped: equippedIds.has(raw.id),
      enchantments: Array.isArray(raw.enchantments) ? raw.enchantments : [],
      updated_at: new Date().toISOString(),
    });
  }

  const { error: deleteError } = await db
    .from('player_items')
    .delete()
    .eq('player_id', auth.playerId);

  if (deleteError) {
    console.error('Inventory delete error:', deleteError);
    return NextResponse.json({ error: 'Failed to replace inventory' }, { status: 500 });
  }

  if (rows.length > 0) {
    const { error: insertError } = await db.from('player_items').insert(rows);
    if (insertError) {
      console.error('Inventory insert error:', insertError);
      return NextResponse.json({ error: 'Failed to insert inventory' }, { status: 500 });
    }
  }

  return NextResponse.json({ success: true, count: rows.length });
}
