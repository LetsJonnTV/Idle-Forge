import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/clans — list all clans
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { data, error } = await supabase
    .from('clans')
    .select('id, name, level, xp, description, created_at, leader:leader_id(id, username)')
    .order('level', { ascending: false })
    .limit(50);

  if (error) {
    console.error('Clans list error:', error);
    return NextResponse.json({ error: 'Failed to fetch clans' }, { status: 500 });
  }

  return NextResponse.json({ clans: data ?? [] });
}

// POST /api/clans — create a new clan (JWT required)
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { name?: string; description?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { name, description = '' } = body;
  if (!name || typeof name !== 'string' || name.trim().length < 2) {
    return NextResponse.json(
      { error: 'Clan name must be at least 2 characters' },
      { status: 400 }
    );
  }

  const cleanName = name.trim();

  // Create clan
  const { data: clan, error: clanError } = await supabase
    .from('clans')
    .insert({ name: cleanName, leader_id: auth.playerId, description })
    .select('id, name, level, xp, description')
    .single();

  if (clanError || !clan) {
    if (clanError?.code === '23505') {
      return NextResponse.json({ error: 'Clan name already taken' }, { status: 409 });
    }
    console.error('Create clan error:', clanError);
    return NextResponse.json({ error: 'Failed to create clan' }, { status: 500 });
  }

  // Add leader as member
  await supabase.from('clan_members').insert({
    clan_id: clan.id,
    player_id: auth.playerId,
  });

  // Update player's clan_id
  await supabase.from('players').update({ clan_id: clan.id }).eq('id', auth.playerId);

  return NextResponse.json({ clan }, { status: 201 });
}
