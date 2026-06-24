import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/prestige_shop — list purchased item IDs for current player
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data, error } = await db
    .from('prestige_purchases')
    .select('item_id, purchased_at')
    .eq('player_id', auth.playerId)
    .order('purchased_at', { ascending: true });

  if (error) {
    console.error('prestige_shop GET error:', error);
    return NextResponse.json({ error: 'Failed to fetch purchases' }, { status: 500 });
  }

  const purchasedIds = (data as { item_id: string }[] ?? []).map((row) => row.item_id);
  return NextResponse.json({ purchasedIds });
}

// POST /api/prestige_shop — record a purchase
// Body: { itemId: string }
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { itemId?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { itemId } = body;
  if (!itemId || typeof itemId !== 'string') {
    return NextResponse.json({ error: 'itemId is required' }, { status: 400 });
  }

  // Check not already purchased
  const { data: existing } = await db
    .from('prestige_purchases')
    .select('item_id')
    .eq('player_id', auth.playerId)
    .eq('item_id', itemId)
    .maybeSingle();

  if (existing) {
    return NextResponse.json({ error: 'Already purchased' }, { status: 409 });
  }

  const { error: insertError } = await db
    .from('prestige_purchases')
    .insert({ player_id: auth.playerId, item_id: itemId });

  if (insertError) {
    console.error('prestige_shop POST error:', insertError);
    return NextResponse.json({ error: 'Failed to record purchase' }, { status: 500 });
  }

  return NextResponse.json({ success: true, itemId }, { status: 201 });
}
