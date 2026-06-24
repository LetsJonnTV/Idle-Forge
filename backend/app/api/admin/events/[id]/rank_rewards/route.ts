import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/admin/events/[id]/rank_rewards
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { id: eventId } = await params;

  const { rows } = await pool.query(
    `SELECT id, rank_from, rank_to, reward_type, amount, item_id, leaderboard_type
     FROM event_rank_rewards WHERE event_id = $1 ORDER BY rank_from ASC`,
    [eventId],
  );
  return NextResponse.json({ rewards: rows });
}

// POST /api/admin/events/[id]/rank_rewards
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { id: eventId } = await params;

  let body: { rank_from?: number; rank_to?: number; reward_type?: string; amount?: number; item_id?: string; leaderboard_type?: string };
  try { body = await request.json(); } catch { return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 }); }

  const { rank_from, rank_to, reward_type, amount, item_id, leaderboard_type = 'solo' } = body;
  if (!rank_from || !rank_to || !reward_type) return NextResponse.json({ error: 'rank_from, rank_to and reward_type are required' }, { status: 400 });
  if (!['gold', 'item'].includes(reward_type)) return NextResponse.json({ error: 'reward_type must be gold or item' }, { status: 400 });
  if (reward_type === 'gold' && (!amount || amount <= 0)) return NextResponse.json({ error: 'amount required for gold' }, { status: 400 });
  if (reward_type === 'item' && !item_id) return NextResponse.json({ error: 'item_id required for item' }, { status: 400 });

  const { rows } = await pool.query(
    `INSERT INTO event_rank_rewards (event_id, rank_from, rank_to, reward_type, amount, item_id, leaderboard_type)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
    [eventId, rank_from, rank_to, reward_type, amount ?? null, item_id ?? null, leaderboard_type],
  );
  return NextResponse.json({ reward: rows[0] }, { status: 201 });
}
