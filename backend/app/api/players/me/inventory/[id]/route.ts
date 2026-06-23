import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// DELETE /api/players/me/inventory/[id] — sell/remove a single item (web frontend)
export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const itemId = params.id;
  if (!itemId) return NextResponse.json({ error: 'Missing item id' }, { status: 400 });

  const { data: existing } = await db
    .from('player_items')
    .select('id, is_locked')
    .eq('id', itemId)
    .eq('player_id', auth.playerId)
    .maybeSingle();

  if (!existing) return NextResponse.json({ error: 'Item not found' }, { status: 404 });
  if (existing.is_locked) return NextResponse.json({ error: 'Item is locked' }, { status: 409 });

  const { error } = await db
    .from('player_items')
    .delete()
    .eq('id', itemId)
    .eq('player_id', auth.playerId);

  if (error) {
    console.error('Delete item error:', error);
    return NextResponse.json({ error: 'Failed to delete item' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}

// PUT /api/players/me/inventory/[id] — equip or unequip an item (web frontend)
// Body: { equip: boolean }
// When equipping, any previously equipped item in the same slot is unequipped first.
export async function PUT(
  request: NextRequest,
  { params }: { params: { id: string } },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const itemId = params.id;
  if (!itemId) return NextResponse.json({ error: 'Missing item id' }, { status: 400 });

  let body: { equip?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (typeof body.equip !== 'boolean') {
    return NextResponse.json({ error: 'equip (boolean) is required' }, { status: 400 });
  }

  const { data: item } = await db
    .from('player_items')
    .select('id, slot')
    .eq('id', itemId)
    .eq('player_id', auth.playerId)
    .maybeSingle();

  if (!item) return NextResponse.json({ error: 'Item not found' }, { status: 404 });

  const now = new Date().toISOString();

  if (body.equip) {
    // Unequip any currently equipped item in the same slot
    const { error: unequipError } = await db
      .from('player_items')
      .update({ is_equipped: false, updated_at: now })
      .eq('player_id', auth.playerId)
      .eq('slot', item.slot)
      .eq('is_equipped', true);

    if (unequipError) {
      console.error('Unequip slot error:', unequipError);
      return NextResponse.json({ error: 'Failed to unequip previous item' }, { status: 500 });
    }
  }

  const { error } = await db
    .from('player_items')
    .update({ is_equipped: body.equip, updated_at: now })
    .eq('id', itemId)
    .eq('player_id', auth.playerId);

  if (error) {
    console.error('Equip item error:', error);
    return NextResponse.json({ error: 'Failed to update equip state' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
