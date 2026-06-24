import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const MAX_ACTIVE_AUCTIONS_PER_PLAYER = 5;
const MIN_PRICE = 10;
const MAX_PRICE = 10_000_000;
const MIN_DURATION_HOURS = 1;
const MAX_DURATION_HOURS = 72;
const DEFAULT_DURATION_HOURS = 24;
const MARKET_FEE_PCT = 0.05; // 5% taken from seller

function processExpiredAuctions(client: Pool) {
  return client.query(
    `UPDATE auctions SET status = 'expired'
     WHERE status = 'active' AND ends_at <= NOW() AND highest_bidder_id IS NULL`,
  );
}

// GET /api/auction — browse active auctions
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const url = request.nextUrl;
  const slot = url.searchParams.get('slot') ?? '';
  const sort = url.searchParams.get('sort') ?? 'ends_asc';
  const page = Math.max(1, parseInt(url.searchParams.get('page') ?? '1', 10));
  const limit = 20;
  const offset = (page - 1) * limit;

  try {
    await processExpiredAuctions(pool);

    const conditions: string[] = ["a.status = 'active'", 'a.ends_at > NOW()'];
    const params: unknown[] = [];
    if (slot) {
      params.push(slot);
      conditions.push(`(a.item_data->>'slot') = $${params.length}`);
    }

    const orderBy =
      sort === 'price_asc'
        ? 'GREATEST(a.current_bid, a.min_price) ASC'
        : sort === 'price_desc'
          ? 'GREATEST(a.current_bid, a.min_price) DESC'
          : sort === 'ends_desc'
            ? 'a.ends_at DESC'
            : 'a.ends_at ASC'; // ends_asc default

    const where = conditions.join(' AND ');
    params.push(limit, offset);

    const { rows } = await pool.query(
      `SELECT a.id, a.seller_id, p.username AS seller_name,
              a.item_data, a.min_price, a.buy_now_price,
              a.current_bid, a.highest_bidder_id,
              hb.username AS highest_bidder_name,
              a.ends_at, a.created_at
       FROM auctions a
       JOIN players p ON p.id = a.seller_id
       LEFT JOIN players hb ON hb.id = a.highest_bidder_id
       WHERE ${where}
       ORDER BY ${orderBy}
       LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params,
    );

    const { rows: countRows } = await pool.query(
      `SELECT COUNT(*)::int AS total FROM auctions a WHERE ${where}`,
      params.slice(0, -2),
    );

    return NextResponse.json({
      auctions: rows.map((a) => ({
        id: a.id,
        sellerId: a.seller_id,
        sellerName: a.seller_name,
        item: a.item_data,
        minPrice: a.min_price,
        buyNowPrice: a.buy_now_price,
        currentBid: a.current_bid,
        highestBidderId: a.highest_bidder_id,
        highestBidderName: a.highest_bidder_name,
        endsAt: a.ends_at,
        createdAt: a.created_at,
      })),
      total: countRows[0]?.total ?? 0,
      page,
      pages: Math.ceil((countRows[0]?.total ?? 0) / limit),
    });
  } catch (err) {
    console.error('auction GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch auctions' }, { status: 500 });
  }
}

// POST /api/auction — list an item for auction
// Body: { item_id, min_price, buy_now_price?, duration_hours? }
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  let body: {
    item_id?: string;
    min_price?: number;
    buy_now_price?: number;
    duration_hours?: number;
  };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { item_id, min_price, buy_now_price, duration_hours = DEFAULT_DURATION_HOURS } = body;

  if (!item_id) return NextResponse.json({ error: 'item_id is required' }, { status: 400 });
  if (!min_price || min_price < MIN_PRICE) {
    return NextResponse.json(
      { error: `min_price must be at least ${MIN_PRICE}` },
      { status: 400 },
    );
  }
  if (min_price > MAX_PRICE) {
    return NextResponse.json({ error: `min_price exceeds maximum` }, { status: 400 });
  }
  if (buy_now_price !== undefined) {
    if (buy_now_price <= min_price) {
      return NextResponse.json(
        { error: 'buy_now_price must exceed min_price' },
        { status: 400 },
      );
    }
    if (buy_now_price > MAX_PRICE) {
      return NextResponse.json({ error: 'buy_now_price exceeds maximum' }, { status: 400 });
    }
  }

  const hours = Math.min(
    Math.max(MIN_DURATION_HOURS, Math.floor(duration_hours)),
    MAX_DURATION_HOURS,
  );
  const endsAt = new Date(Date.now() + hours * 3_600_000);

  try {
    // Enforce per-player active auction limit
    const { rows: activeCount } = await pool.query<{ count: string }>(
      `SELECT COUNT(*)::int AS count FROM auctions WHERE seller_id = $1 AND status = 'active'`,
      [auth.playerId],
    );
    if (Number(activeCount[0]?.count ?? 0) >= MAX_ACTIVE_AUCTIONS_PER_PLAYER) {
      return NextResponse.json(
        { error: `You may only have ${MAX_ACTIVE_AUCTIONS_PER_PLAYER} active auctions at once` },
        { status: 409 },
      );
    }

    // Fetch item from seller's inventory
    const { rows: itemRows } = await pool.query(
      `SELECT id, player_id, slot, tier, set_id, power, sell_value,
              name, icon_path, is_locked, is_equipped, enchantments
       FROM player_items
       WHERE id = $1 AND player_id = $2`,
      [item_id, auth.playerId],
    );
    if (itemRows.length === 0) {
      return NextResponse.json({ error: 'Item not found in your inventory' }, { status: 404 });
    }
    const item = itemRows[0];
    if (item.is_locked) {
      return NextResponse.json({ error: 'Cannot auction a locked item' }, { status: 409 });
    }
    if (item.is_equipped) {
      return NextResponse.json({ error: 'Cannot auction an equipped item' }, { status: 409 });
    }

    const itemData = {
      id: item.id,
      slot: item.slot,
      tier: item.tier,
      setId: item.set_id,
      power: item.power,
      sellValue: item.sell_value,
      name: item.name,
      iconPath: item.icon_path,
      enchantments: item.enchantments,
    };

    await pool.query('BEGIN');
    try {
      // Remove from seller's inventory
      await pool.query(`DELETE FROM player_items WHERE id = $1 AND player_id = $2`, [
        item_id,
        auth.playerId,
      ]);

      // Create auction
      const { rows: auctionRows } = await pool.query(
        `INSERT INTO auctions (seller_id, item_data, min_price, buy_now_price, ends_at)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, seller_id, item_data, min_price, buy_now_price, current_bid, ends_at, status, created_at`,
        [
          auth.playerId,
          JSON.stringify(itemData),
          min_price,
          buy_now_price ?? null,
          endsAt.toISOString(),
        ],
      );

      await pool.query('COMMIT');
      return NextResponse.json({ auction: auctionRows[0] }, { status: 201 });
    } catch (e) {
      await pool.query('ROLLBACK');
      throw e;
    }
  } catch (err) {
    console.error('auction POST error:', err);
    return NextResponse.json({ error: 'Failed to create auction' }, { status: 500 });
  }
}

