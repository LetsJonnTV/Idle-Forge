import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// GET /api/players/[id] — public profile
export async function GET(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { data: player, error } = await supabase
    .from('players')
    .select('id, username, total_strength, prestige_level, chapter, clan_id')
    .eq('id', params.id)
    .maybeSingle();

  if (error || !player) {
    return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  }

  return NextResponse.json(player);
}

// PUT /api/players/[id] — upload stats (JWT required, own profile only)
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  if (auth.playerId !== params.id) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  let body: { total_strength?: number; prestige_level?: number; chapter?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  // Validate — only accept non-negative integers
  const updates: Record<string, number> = {};
  if (typeof body.total_strength === 'number' && body.total_strength >= 0) {
    updates.total_strength = Math.floor(body.total_strength);
  }
  if (typeof body.prestige_level === 'number' && body.prestige_level >= 0) {
    updates.prestige_level = Math.floor(body.prestige_level);
  }
  if (typeof body.chapter === 'number' && body.chapter >= 1) {
    updates.chapter = Math.floor(body.chapter);
  }

  if (Object.keys(updates).length === 0) {
    return NextResponse.json({ error: 'No valid fields to update' }, { status: 400 });
  }

  const { data, error } = await supabase
    .from('players')
    .update(updates)
    .eq('id', params.id)
    .select('id, username, total_strength, prestige_level, chapter')
    .single();

  if (error || !data) {
    console.error('Stats upload error:', error);
    return NextResponse.json({ error: 'Failed to update stats' }, { status: 500 });
  }

  return NextResponse.json(data);
}
