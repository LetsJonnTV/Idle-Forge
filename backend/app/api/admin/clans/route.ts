import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/dbClient';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

async function requireAdmin(request: NextRequest) {
  const auth = await getAuthPayload(request);
  if (!auth) return null;
  const { data: player } = await db.from('players').select('is_admin').eq('id', auth.playerId).single();
  if (!player?.is_admin) return null;
  return auth;
}

// GET /api/admin/clans — list all clans with member count
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await requireAdmin(request);
  if (!auth) return NextResponse.json({ error: 'Forbidden' }, { status: 403 });

  const url = new URL(request.url);
  const search = url.searchParams.get('q')?.trim() ?? '';

  let query = db
    .from('clans')
    .select('id, name, level, xp, description, created_at, leader:leader_id(id, username)')
    .order('created_at', { ascending: false })
    .limit(100);

  if (search) {
    query = query.ilike('name', `%${search}%`);
  }

  const { data, error } = await query;

  if (error) {
    console.error('Admin clans list error:', error);
    return NextResponse.json({ error: 'Failed to fetch clans' }, { status: 500 });
  }

  // Fetch member counts separately
  const clans = data ?? [];
  const counts: Record<string, number> = {};
  if (clans.length > 0) {
    const ids = clans.map((c: any) => c.id);
    for (const id of ids) {
      const { data: members } = await db
        .from('clan_members')
        .select('player_id')
        .eq('clan_id', id);
      counts[id] = (members as any[])?.length ?? 0;
    }
  }

  const result = clans.map((c: any) => ({ ...c, member_count: counts[c.id] ?? 0 }));

  return NextResponse.json({ clans: result });
}
