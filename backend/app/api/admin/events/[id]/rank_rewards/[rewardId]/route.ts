import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// DELETE /api/admin/events/[id]/rank_rewards/[rewardId]
export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ id: string; rewardId: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const { rewardId } = await params;
  const { rowCount } = await pool.query(`DELETE FROM event_rank_rewards WHERE id = $1`, [rewardId]);
  if (!rowCount) return NextResponse.json({ error: 'Not found' }, { status: 404 });
  return NextResponse.json({ success: true });
}
