import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const WAR_DURATION_DAYS = 7;

// GET /api/admin/clan_wars — list all wars (past + active)
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  try {
    // Expire finished wars before listing
    await pool.query(
      `UPDATE clan_wars
       SET status = 'completed',
           winner_clan_id = CASE
             WHEN clan_a_points > clan_b_points THEN clan_a_id
             WHEN clan_b_points > clan_a_points THEN clan_b_id
             ELSE NULL
           END
       WHERE status = 'active' AND ends_at <= NOW()`,
    );

    const { rows } = await pool.query(
      `SELECT cw.id, cw.status, cw.started_at, cw.ends_at,
              cw.clan_a_points, cw.clan_b_points, cw.winner_clan_id,
              ca.name AS clan_a_name, cb.name AS clan_b_name,
              wc.name AS winner_name,
              COUNT(cwc.player_id)::int AS participant_count
       FROM clan_wars cw
       JOIN clans ca ON ca.id = cw.clan_a_id
       JOIN clans cb ON cb.id = cw.clan_b_id
       LEFT JOIN clans wc ON wc.id = cw.winner_clan_id
       LEFT JOIN clan_war_contributions cwc ON cwc.war_id = cw.id
       GROUP BY cw.id, ca.name, cb.name, wc.name
       ORDER BY cw.started_at DESC
       LIMIT 50`,
    );
    return NextResponse.json({ wars: rows });
  } catch (err) {
    console.error('admin clan_wars GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch clan wars' }, { status: 500 });
  }
}

// POST /api/admin/clan_wars — create a new war between two clans
// Body: { clan_a_id, clan_b_id, duration_days? }
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  let body: { clan_a_id?: string; clan_b_id?: string; duration_days?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { clan_a_id, clan_b_id, duration_days = WAR_DURATION_DAYS } = body;

  if (!clan_a_id || !clan_b_id) {
    return NextResponse.json({ error: 'clan_a_id and clan_b_id are required' }, { status: 400 });
  }
  if (clan_a_id === clan_b_id) {
    return NextResponse.json({ error: 'Clans must be different' }, { status: 400 });
  }

  const days = Math.min(Math.max(1, Math.floor(duration_days)), 30);
  const endsAt = new Date(Date.now() + days * 86_400_000);

  try {
    // Check both clans exist
    const { rows: clans } = await pool.query(
      `SELECT id FROM clans WHERE id = ANY($1::uuid[])`,
      [[clan_a_id, clan_b_id]],
    );
    if (clans.length < 2) {
      return NextResponse.json({ error: 'One or both clans not found' }, { status: 404 });
    }

    // Check neither clan is already in an active war
    const { rows: activeWars } = await pool.query(
      `SELECT id FROM clan_wars
       WHERE status = 'active'
         AND ends_at > NOW()
         AND (clan_a_id = ANY($1::uuid[]) OR clan_b_id = ANY($1::uuid[]))`,
      [[clan_a_id, clan_b_id]],
    );
    if (activeWars.length > 0) {
      return NextResponse.json(
        { error: 'One or both clans are already in an active war' },
        { status: 409 },
      );
    }

    const { rows } = await pool.query(
      `INSERT INTO clan_wars (clan_a_id, clan_b_id, ends_at)
       VALUES ($1, $2, $3)
       RETURNING id, clan_a_id, clan_b_id, started_at, ends_at, status`,
      [clan_a_id, clan_b_id, endsAt.toISOString()],
    );

    return NextResponse.json({ war: rows[0] }, { status: 201 });
  } catch (err) {
    console.error('admin clan_wars POST error:', err);
    return NextResponse.json({ error: 'Failed to create clan war' }, { status: 500 });
  }
}

// DELETE /api/admin/clan_wars?id=<warId> — cancel an active war
export async function DELETE(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const warId = request.nextUrl.searchParams.get('id');
  if (!warId) return NextResponse.json({ error: 'id is required' }, { status: 400 });

  try {
    const { rows } = await pool.query(
      `UPDATE clan_wars SET status = 'completed' WHERE id = $1 AND status = 'active' RETURNING id`,
      [warId],
    );
    if (rows.length === 0) {
      return NextResponse.json({ error: 'Active war not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true });
  } catch (err) {
    console.error('admin clan_wars DELETE error:', err);
    return NextResponse.json({ error: 'Failed to cancel war' }, { status: 500 });
  }
}
