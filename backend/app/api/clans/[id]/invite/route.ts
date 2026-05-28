import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// POST /api/clans/[id]/invite — invite player by username (JWT required, leader only)
// Body: { username: string }
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { id: clanId } = params;

  // Verify caller is the clan leader
  const { data: clan } = await supabase
    .from('clans')
    .select('id, leader_id')
    .eq('id', clanId)
    .single();

  if (!clan) {
    return NextResponse.json({ error: 'Clan not found' }, { status: 404 });
  }

  if (clan.leader_id !== auth.playerId) {
    return NextResponse.json({ error: 'Only the clan leader can invite players' }, { status: 403 });
  }

  let body: { username?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { username } = body;
  if (!username || typeof username !== 'string' || username.trim().length === 0) {
    return NextResponse.json({ error: 'Username is required' }, { status: 400 });
  }

  // Find the target player
  const { data: invitee } = await supabase
    .from('players')
    .select('id, username, clan_id')
    .eq('username', username.trim())
    .maybeSingle();

  if (!invitee) {
    return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  }

  if (invitee.id === auth.playerId) {
    return NextResponse.json({ error: 'Cannot invite yourself' }, { status: 400 });
  }

  if (invitee.clan_id) {
    return NextResponse.json({ error: 'Player is already in a clan' }, { status: 409 });
  }

  // Check for existing pending invite
  const { data: existingInvite } = await supabase
    .from('clan_invites')
    .select('id, status')
    .eq('clan_id', clanId)
    .eq('invitee_id', invitee.id)
    .maybeSingle();

  if (existingInvite && existingInvite.status === 'pending') {
    return NextResponse.json({ error: 'Invite already sent to this player' }, { status: 409 });
  }

  // Upsert invite
  const { error: inviteError } = await supabase
    .from('clan_invites')
    .upsert(
      {
        clan_id: clanId,
        invitee_id: invitee.id,
        inviter_id: auth.playerId,
        status: 'pending',
      },
      { onConflict: 'clan_id,invitee_id' }
    );

  if (inviteError) {
    console.error('Clan invite error:', inviteError);
    return NextResponse.json({ error: 'Failed to send invite' }, { status: 500 });
  }

  return NextResponse.json({ message: 'Invite sent' }, { status: 201 });
}
