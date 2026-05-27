import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// GET /api/clans/[id] — clan details
export async function GET(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { data: clan, error } = await supabase
    .from('clans')
    .select('id, name, level, xp, description, created_at, leader:leader_id(id, username)')
    .eq('id', params.id)
    .maybeSingle();

  if (error || !clan) {
    return NextResponse.json({ error: 'Clan not found' }, { status: 404 });
  }

  return NextResponse.json({ clan });
}

// PUT /api/clans/[id] — update clan perks/description (leader only, JWT required)
export async function PUT(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  // Verify leadership
  const { data: clan } = await supabase
    .from('clans')
    .select('id, leader_id')
    .eq('id', params.id)
    .maybeSingle();

  if (!clan) return NextResponse.json({ error: 'Clan not found' }, { status: 404 });
  if (clan.leader_id !== auth.playerId) {
    return NextResponse.json({ error: 'Only the clan leader can update the clan' }, { status: 403 });
  }

  let body: { description?: string; xp?: number; level?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const updates: Record<string, unknown> = {};
  if (typeof body.description === 'string') updates.description = body.description;
  if (typeof body.xp === 'number' && body.xp >= 0) updates.xp = Math.floor(body.xp);
  if (typeof body.level === 'number' && body.level >= 1) updates.level = Math.floor(body.level);

  if (Object.keys(updates).length === 0) {
    return NextResponse.json({ error: 'No valid fields to update' }, { status: 400 });
  }

  const { data: updated, error: updateError } = await supabase
    .from('clans')
    .update(updates)
    .eq('id', params.id)
    .select('id, name, level, xp, description')
    .single();

  if (updateError || !updated) {
    return NextResponse.json({ error: 'Failed to update clan' }, { status: 500 });
  }

  return NextResponse.json({ clan: updated });
}
