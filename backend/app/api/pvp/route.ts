import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const RANDOM_FACTOR = 0.15; // ±15%

function calculatePvpWinner(
  challengerId: string,
  challengerStrength: number,
  defenderId: string,
  defenderStrength: number
): string {
  const rand = () => 1 + (Math.random() * 2 - 1) * RANDOM_FACTOR;
  const effectiveChallenger = challengerStrength * rand();
  const effectiveDefender = defenderStrength * rand();
  return effectiveChallenger >= effectiveDefender ? challengerId : defenderId;
}

// GET /api/pvp — list open/pending battles for the authenticated player
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { data, error } = await db
    .from('pvp_battles')
    .select(
      `id, status, created_at, challenger_strength, defender_strength,
       winner_id,
       challenger:challenger_id(id, username),
       defender:defender_id(id, username)`
    )
    .or(`challenger_id.eq.${auth.playerId},defender_id.eq.${auth.playerId}`)
    .order('created_at', { ascending: false })
    .limit(20);

  if (error) {
    console.error('PVP list error:', error);
    return NextResponse.json({ error: 'Failed to fetch battles' }, { status: 500 });
  }

  return NextResponse.json({ battles: data ?? [] });
}

// POST /api/pvp — challenge a player
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: { defenderUsername?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { defenderUsername } = body;
  if (!defenderUsername) {
    return NextResponse.json({ error: 'defenderUsername is required' }, { status: 400 });
  }

  // Resolve defender
  const { data: defender } = await db
    .from('players')
    .select('id, username, total_strength')
    .eq('username', defenderUsername.trim().toLowerCase())
    .maybeSingle();

  if (!defender) return NextResponse.json({ error: 'Player not found' }, { status: 404 });
  if (defender.id === auth.playerId) {
    return NextResponse.json({ error: 'Cannot challenge yourself' }, { status: 400 });
  }

  // Get challenger's strength
  const { data: challenger } = await db
    .from('players')
    .select('total_strength')
    .eq('id', auth.playerId)
    .maybeSingle();

  const challengerStrength = challenger?.total_strength ?? 0;
  const defenderStrength = defender.total_strength ?? 0;

  // Server-side battle resolution
  const winnerId = calculatePvpWinner(
    auth.playerId,
    challengerStrength,
    defender.id,
    defenderStrength
  );

  const { data: battle, error: insertError } = await db
    .from('pvp_battles')
    .insert({
      challenger_id: auth.playerId,
      defender_id: defender.id,
      winner_id: winnerId,
      challenger_strength: challengerStrength,
      defender_strength: defenderStrength,
      status: 'completed',
    })
    .select()
    .single();

  if (insertError || !battle) {
    console.error('PVP challenge error:', insertError);
    return NextResponse.json({ error: 'Failed to create battle' }, { status: 500 });
  }

  return NextResponse.json(
    {
      battle,
      result: {
        winnerId,
        challengerWon: winnerId === auth.playerId,
        challengerStrength,
        defenderStrength,
      },
    },
    { status: 201 }
  );
}
