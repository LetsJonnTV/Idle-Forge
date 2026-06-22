import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// GET /api/coop/[id] — session status
export async function GET(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: session, error } = await db
    .from('coop_sessions')
    .select(
      `id, status, boss_hp, created_at,
       host:host_id(id, username),
       guest:guest_id(id, username)`
    )
    .eq('id', params.id)
    .maybeSingle();

  if (error || !session) {
    return NextResponse.json({ error: 'Session not found' }, { status: 404 });
  }

  const hostRaw = session.host;
  const guestRaw = session.guest;
  const hostId = (Array.isArray(hostRaw) ? hostRaw[0] : hostRaw as { id: string } | null)?.id;
  const guestId = (Array.isArray(guestRaw) ? guestRaw[0] : guestRaw as { id: string } | null)?.id;
  const isParticipant = hostId === auth.playerId || guestId === auth.playerId;

  if (!isParticipant) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  return NextResponse.json({ session });
}

// PUT /api/coop/[id] — join a session or update status
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: session } = await db
    .from('coop_sessions')
    .select('id, host_id, guest_id, status')
    .eq('id', params.id)
    .maybeSingle();

  if (!session) return NextResponse.json({ error: 'Session not found' }, { status: 404 });

  let body: { action?: 'join' | 'complete' };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  if (body.action === 'join') {
    if (session.status !== 'waiting') {
      return NextResponse.json({ error: 'Session is not open for joining' }, { status: 409 });
    }
    if (session.host_id === auth.playerId) {
      return NextResponse.json({ error: 'You are the host' }, { status: 400 });
    }
    if (session.guest_id) {
      return NextResponse.json({ error: 'Session already has a guest' }, { status: 409 });
    }

    const { data: updated, error: updateError } = await db
      .from('coop_sessions')
      .update({ guest_id: auth.playerId, status: 'active' })
      .eq('id', params.id)
      .eq('status', 'waiting')
      .is('guest_id', null)
      .select()
      .single();

    if (!updated) {
      return NextResponse.json(
        { error: 'Session is not open for joining' },
        { status: 409 },
      );
    }

    if (updateError) {
      return NextResponse.json({ error: 'Failed to join session' }, { status: 500 });
    }

    return NextResponse.json({ session: updated });
  }

  if (body.action === 'complete') {
    const isParticipant =
      session.host_id === auth.playerId || session.guest_id === auth.playerId;
    if (!isParticipant) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

    const { data: updated } = await db
      .from('coop_sessions')
      .update({ status: 'completed' })
      .eq('id', params.id)
      .select()
      .single();

    return NextResponse.json({ session: updated });
  }

  return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
}
