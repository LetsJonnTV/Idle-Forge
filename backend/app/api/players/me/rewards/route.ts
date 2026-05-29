import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// POST /api/players/me/rewards — fetch and atomically consume all pending rewards
// Returns: { rewards: Array<{ reward_type, amount?, item_id? }> }
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  // Fetch all pending rewards for this player
  const { data: rewards, error: fetchError } = await supabase
    .from('pending_rewards')
    .select('id, reward_type, amount, item_id')
    .eq('player_id', auth.playerId);

  if (fetchError) {
    console.error('Fetch pending rewards error:', fetchError);
    return NextResponse.json({ error: 'Failed to fetch rewards' }, { status: 500 });
  }

  if (!rewards || rewards.length === 0) {
    return NextResponse.json({ rewards: [] });
  }

  // Delete all fetched rewards atomically
  const ids = rewards.map((r) => r.id);
  const { error: deleteError } = await supabase
    .from('pending_rewards')
    .delete()
    .in('id', ids);

  if (deleteError) {
    console.error('Delete pending rewards error:', deleteError);
    return NextResponse.json({ error: 'Failed to claim rewards' }, { status: 500 });
  }

  return NextResponse.json({ rewards });
}
