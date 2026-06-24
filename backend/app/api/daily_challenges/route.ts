import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

function todayUtc(): string {
  return new Date().toISOString().slice(0, 10); // 'YYYY-MM-DD'
}

// GET /api/daily_challenges — get or create today's challenge record
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const today = todayUtc();

  // Upsert today's record (creates if not exists, leaves existing as-is)
  const { data, error } = await db
    .from('daily_challenges')
    .upsert(
      {
        player_id: auth.playerId,
        date: today,
        kills_progress: 0,
        crafts_progress: 0,
        boss_progress: 0,
        kills_claimed: false,
        crafts_claimed: false,
        boss_claimed: false,
      },
      { onConflict: 'player_id,date' },
    )
    .select()
    .single();

  if (error || !data) {
    console.error('daily_challenges GET error:', error);
    return NextResponse.json({ error: 'Failed to fetch challenges' }, { status: 500 });
  }

  return NextResponse.json({ challenge: data });
}

// POST /api/daily_challenges — sync progress and optionally claim
// Body: { kills_progress?, crafts_progress?, boss_progress?, claim?: 'kills'|'crafts'|'boss' }
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: {
    kills_progress?: number;
    crafts_progress?: number;
    boss_progress?: number;
    claim?: 'kills' | 'crafts' | 'boss';
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const today = todayUtc();

  // Get current record (create if it doesn't exist yet)
  const { data: existing } = await db
    .from('daily_challenges')
    .upsert(
      {
        player_id: auth.playerId,
        date: today,
        kills_progress: 0,
        crafts_progress: 0,
        boss_progress: 0,
        kills_claimed: false,
        crafts_claimed: false,
        boss_claimed: false,
      },
      { onConflict: 'player_id,date' },
    )
    .select()
    .single();

  if (!existing) {
    return NextResponse.json({ error: 'Failed to initialize challenge' }, { status: 500 });
  }

  // Build update payload
  const update: Record<string, number | boolean> = {};

  if (body.kills_progress !== undefined) {
    update['kills_progress'] = Math.max(existing.kills_progress as number, body.kills_progress);
  }
  if (body.crafts_progress !== undefined) {
    update['crafts_progress'] = Math.max(existing.crafts_progress as number, body.crafts_progress);
  }
  if (body.boss_progress !== undefined) {
    update['boss_progress'] = Math.max(existing.boss_progress as number, body.boss_progress);
  }

  // Handle claim
  const TARGETS = { kills: 50, crafts: 30, boss: 3 } as const;
  if (body.claim) {
    const type = body.claim;
    const claimedKey = `${type}_claimed` as 'kills_claimed' | 'crafts_claimed' | 'boss_claimed';
    const progressKey = `${type}_progress` as 'kills_progress' | 'crafts_progress' | 'boss_progress';

    if (existing[claimedKey]) {
      return NextResponse.json({ error: 'Already claimed' }, { status: 400 });
    }

    const progress = (update[progressKey] as number | undefined) ?? (existing[progressKey] as number);
    if (progress < TARGETS[type]) {
      return NextResponse.json({ error: 'Target not reached' }, { status: 400 });
    }

    update[claimedKey] = true;
  }

  if (Object.keys(update).length === 0) {
    return NextResponse.json({ challenge: existing });
  }

  const { data: updated, error: updateError } = await db
    .from('daily_challenges')
    .update(update)
    .eq('player_id', auth.playerId)
    .eq('date', today)
    .select()
    .single();

  if (updateError || !updated) {
    console.error('daily_challenges POST update error:', updateError);
    return NextResponse.json({ error: 'Failed to update challenge' }, { status: 500 });
  }

  return NextResponse.json({ challenge: updated });
}
