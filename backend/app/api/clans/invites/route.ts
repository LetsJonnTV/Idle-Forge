import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/clans/invites — list pending invites for current player (JWT required)
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data, error } = await supabase
    .from('clan_invites')
    .select(`
      id,
      status,
      created_at,
      clan:clan_id(id, name, level, description),
      inviter:inviter_id(id, username)
    `)
    .eq('invitee_id', auth.playerId)
    .eq('status', 'pending')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Get invites error:', error);
    return NextResponse.json({ error: 'Failed to fetch invites' }, { status: 500 });
  }

  return NextResponse.json({ invites: data ?? [] });
}

// PUT /api/clans/invites — respond to an invite
// Body: { inviteId: string, accept: boolean }
export async function PUT(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { inviteId?: string; accept?: boolean };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { inviteId, accept } = body;
  if (!inviteId || typeof accept !== 'boolean') {
    return NextResponse.json({ error: 'inviteId and accept are required' }, { status: 400 });
  }

  // Fetch the invite
  const { data: invite } = await supabase
    .from('clan_invites')
    .select('id, clan_id, invitee_id, status')
    .eq('id', inviteId)
    .eq('invitee_id', auth.playerId)
    .maybeSingle();

  if (!invite) {
    return NextResponse.json({ error: 'Invite not found' }, { status: 404 });
  }

  if (invite.status !== 'pending') {
    return NextResponse.json({ error: 'Invite is no longer pending' }, { status: 400 });
  }

  const newStatus = accept ? 'accepted' : 'declined';

  // Update invite status
  await supabase
    .from('clan_invites')
    .update({ status: newStatus })
    .eq('id', inviteId);

  if (accept) {
    // Add player to clan
    await supabase.from('clan_members').insert({
      clan_id: invite.clan_id,
      player_id: auth.playerId,
    });

    // Update player's clan_id
    await supabase
      .from('players')
      .update({ clan_id: invite.clan_id })
      .eq('id', auth.playerId);
  }

  return NextResponse.json({ message: accept ? 'Invite accepted' : 'Invite declined' });
}
