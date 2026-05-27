import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/leaderboard?scope=weekly
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { searchParams } = new URL(request.url);
  const scope = searchParams.get('scope'); // 'weekly' | null

  // For weekly: filter by players created/active in the last 7 days.
  // We use created_at as a proxy for "active this week" since we don't track login time yet.
  let query = supabase
    .from('players')
    .select('id, username, total_strength, prestige_level, chapter')
    .order('total_strength', { ascending: false })
    .limit(100);

  if (scope === 'weekly') {
    const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    query = query.gte('created_at', weekAgo);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Leaderboard error:', error);
    return NextResponse.json({ error: 'Failed to fetch leaderboard' }, { status: 500 });
  }

  const entries = (data ?? []).map((p, idx) => ({
    rank: idx + 1,
    id: p.id,
    username: p.username,
    totalStrength: p.total_strength,
    prestigeLevel: p.prestige_level,
    chapter: p.chapter,
  }));

  return NextResponse.json({ entries, scope: scope ?? 'global' });
}
