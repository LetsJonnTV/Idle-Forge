import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

// GET /api/admin/players — list all players
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  const { searchParams } = new URL(request.url);
  const search = searchParams.get('q')?.trim().toLowerCase();

  let query = db
    .from('players')
    .select('id, username, is_admin, is_blocked, total_strength, prestige_level, chapter, created_at')
    .order('created_at', { ascending: false });

  if (search) {
    query = query.ilike('username', `%${search}%`);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Admin list players error:', error);
    return NextResponse.json({ error: 'Failed to fetch players' }, { status: 500 });
  }

  return NextResponse.json({ players: data ?? [] });
}
