import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/saves — load game save for the authenticated player
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const { data, error } = await supabase
    .from('game_saves')
    .select('save_data, updated_at')
    .eq('player_id', auth.playerId)
    .maybeSingle();

  if (error) {
    console.error('Load save error:', error);
    return NextResponse.json({ error: 'Failed to load save' }, { status: 500 });
  }

  if (!data) {
    return NextResponse.json({ save: null, pendingRewards: [] });
  }

  // Fetch and consume pending rewards
  const { data: rewards } = await supabase
    .from('pending_rewards')
    .select('id, reward_type, amount, item_id, given_by, created_at')
    .eq('player_id', auth.playerId)
    .order('created_at', { ascending: true });

  if (rewards && rewards.length > 0) {
    const ids = rewards.map((r: { id: string }) => r.id);
    await supabase.from('pending_rewards').delete().in('id', ids);
  }

  return NextResponse.json({
    save: data.save_data,
    updatedAt: data.updated_at,
    pendingRewards: rewards ?? [],
  });
}

// PUT /api/saves — upload/overwrite game save for the authenticated player
export async function PUT(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  let body: { save_data?: unknown };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (
    !body.save_data ||
    typeof body.save_data !== 'object' ||
    Array.isArray(body.save_data)
  ) {
    return NextResponse.json(
      { error: 'save_data must be a non-null object' },
      { status: 400 },
    );
  }

  const { error } = await supabase.from('game_saves').upsert(
    {
      player_id: auth.playerId,
      save_data: body.save_data,
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'player_id' },
  );

  if (error) {
    console.error('Upload save error:', error);
    return NextResponse.json({ error: 'Failed to save' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
