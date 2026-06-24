import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

async function requireAdmin(request: NextRequest) {
  const auth = await getAuthPayload(request);
  if (!auth) return null;
  const { data: player } = await db.from('players').select('is_admin').eq('id', auth.playerId).single();
  if (!player?.is_admin) return null;
  return auth;
}

// GET /api/admin/clans/[id] — get clan members
export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await requireAdmin(request);
  if (!auth) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id } = params;

  const { data: clan, error: clanError } = await db
    .from('clans')
    .select('id, name, level, xp, description, created_at, leader:leader_id(id, username)')
    .eq('id', id)
    .single();

  if (clanError || !clan) {
    return NextResponse.json({ error: 'Clan not found' }, { status: 404 });
  }

  const { data: members, error: membersError } = await db
    .from('clan_members')
    .select('player_id, joined_at, player:player_id(id, username, total_strength, prestige_level, chapter)')
    .eq('clan_id', id)
    .order('joined_at', { ascending: true });

  if (membersError) {
    console.error('Admin clan members error:', membersError);
    return NextResponse.json({ error: 'Failed to fetch members' }, { status: 500 });
  }

  return NextResponse.json({ clan, members: members ?? [] });
}

// DELETE /api/admin/clans/[id] — delete a clan
export async function DELETE(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await requireAdmin(request);
  if (!auth) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id } = params;

  const { error } = await db.from('clans').delete().eq('id', id);

  if (error) {
    console.error('Admin delete clan error:', error);
    return NextResponse.json({ error: 'Failed to delete clan' }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}

// PATCH /api/admin/clans/[id] — kick a member
export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await requireAdmin(request);
  if (!auth) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const { id } = params;

  let body: { kick_player_id?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { kick_player_id } = body;
  if (!kick_player_id) {
    return NextResponse.json({ error: 'kick_player_id required' }, { status: 400 });
  }

  // Remove from clan_members
  const { error: memberError } = await db
    .from('clan_members')
    .delete()
    .eq('clan_id', id)
    .eq('player_id', kick_player_id);

  if (memberError) {
    console.error('Admin kick member error:', memberError);
    return NextResponse.json({ error: 'Failed to kick member' }, { status: 500 });
  }

  // Clear player's clan_id
  await db.from('players').update({ clan_id: null }).eq('id', kick_player_id);

  return NextResponse.json({ success: true });
}
