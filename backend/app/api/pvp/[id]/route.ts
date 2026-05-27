import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

interface RouteParams {
  params: { id: string };
}

// GET /api/pvp/[id] — get a specific battle result
export async function GET(request: NextRequest, { params }: RouteParams) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data: battle, error } = await supabase
    .from('pvp_battles')
    .select(
      `id, status, created_at, challenger_strength, defender_strength, winner_id,
       challenger:challenger_id(id, username),
       defender:defender_id(id, username)`
    )
    .eq('id', params.id)
    .maybeSingle();

  if (error || !battle) {
    return NextResponse.json({ error: 'Battle not found' }, { status: 404 });
  }

  // Only participants can view
  const challengerRaw = battle.challenger;
  const defenderRaw = battle.defender;
  const challengerId = (Array.isArray(challengerRaw) ? challengerRaw[0] : challengerRaw as { id: string } | null)?.id;
  const defenderId = (Array.isArray(defenderRaw) ? defenderRaw[0] : defenderRaw as { id: string } | null)?.id;
  const isParticipant = challengerId === auth.playerId || defenderId === auth.playerId;

  if (!isParticipant) {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 });
  }

  return NextResponse.json({ battle });
}
