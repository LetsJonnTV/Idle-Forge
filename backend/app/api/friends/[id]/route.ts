import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// PUT /api/friends/[id] — accept or block a friend request
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { action?: 'accept' | 'block' | 'reject' };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { action } = body;
  if (!action || !['accept', 'block', 'reject'].includes(action)) {
    return NextResponse.json(
      { error: 'action must be accept, block, or reject' },
      { status: 400 }
    );
  }

  // Fetch the relationship — must be addressee to respond
  const { data: friendship, error: fetchError } = await db
    .from('friends')
    .select('id, requester_id, addressee_id, status')
    .eq('id', params.id)
    .maybeSingle();

  if (fetchError || !friendship) {
    return NextResponse.json({ error: 'Friend request not found' }, { status: 404 });
  }

  if (friendship.addressee_id !== auth.playerId) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  if (action === 'reject') {
    // Delete the request
    await db.from('friends').delete().eq('id', params.id);
    return NextResponse.json({ message: 'Request rejected' });
  }

  const newStatus = action === 'accept' ? 'accepted' : 'blocked';

  const { data: updated, error: updateError } = await db
    .from('friends')
    .update({ status: newStatus })
    .eq('id', params.id)
    .select()
    .single();

  if (updateError || !updated) {
    return NextResponse.json({ error: 'Failed to update relationship' }, { status: 500 });
  }

  return NextResponse.json({ friendship: updated });
}
