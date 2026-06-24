import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { requireAdmin } from '@/lib/adminAuth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/admin/auctions — list all auctions with stats
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const url = request.nextUrl;
  const status = url.searchParams.get('status') ?? 'active';
  const page = Math.max(1, parseInt(url.searchParams.get('page') ?? '1', 10));
  const limit = 25;
  const offset = (page - 1) * limit;

  const validStatuses = ['active', 'sold', 'expired', 'cancelled', 'all'];
  const filterStatus = validStatuses.includes(status) ? status : 'all';

  try {
    const where = filterStatus === 'all' ? '' : `WHERE a.status = '${filterStatus}'`;

    const { rows } = await pool.query(
      `SELECT a.id, a.status, a.item_data, a.min_price, a.buy_now_price,
              a.current_bid, a.claimed, a.ends_at, a.created_at,
              s.username AS seller_name, a.seller_id,
              hb.username AS highest_bidder_name, a.highest_bidder_id,
              COUNT(ab.id)::int AS bid_count
       FROM auctions a
       JOIN players s ON s.id = a.seller_id
       LEFT JOIN players hb ON hb.id = a.highest_bidder_id
       LEFT JOIN auction_bids ab ON ab.auction_id = a.id
       ${where}
       GROUP BY a.id, s.username, hb.username
       ORDER BY a.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset],
    );

    const { rows: stats } = await pool.query(
      `SELECT
         COUNT(*) FILTER (WHERE status = 'active')::int AS active,
         COUNT(*) FILTER (WHERE status = 'sold')::int AS sold,
         COUNT(*) FILTER (WHERE status = 'expired')::int AS expired,
         COUNT(*) FILTER (WHERE status = 'cancelled')::int AS cancelled,
         COALESCE(SUM(current_bid) FILTER (WHERE status = 'sold'), 0)::bigint AS total_volume
       FROM auctions`,
    );

    return NextResponse.json({
      auctions: rows.map((a) => ({
        id: a.id,
        status: a.status,
        item: a.item_data,
        minPrice: a.min_price,
        buyNowPrice: a.buy_now_price,
        currentBid: a.current_bid,
        bidCount: a.bid_count,
        claimed: a.claimed,
        endsAt: a.ends_at,
        createdAt: a.created_at,
        sellerName: a.seller_name,
        sellerId: a.seller_id,
        highestBidderName: a.highest_bidder_name,
        highestBidderId: a.highest_bidder_id,
      })),
      stats: stats[0],
      page,
    });
  } catch (err) {
    console.error('admin auctions GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch auctions' }, { status: 500 });
  }
}

// DELETE /api/admin/auctions?id=<auctionId> — admin force-cancel an auction
export async function DELETE(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError } = await requireAdmin(request);
  if (authError) return authError;

  const auctionId = request.nextUrl.searchParams.get('id');
  if (!auctionId) return NextResponse.json({ error: 'id is required' }, { status: 400 });

  try {
    const { rows } = await pool.query(
      `SELECT * FROM auctions WHERE id = $1 AND status = 'active'`,
      [auctionId],
    );
    if (rows.length === 0) {
      return NextResponse.json({ error: 'Active auction not found' }, { status: 404 });
    }
    const auction = rows[0];

    await pool.query('BEGIN');
    try {
      await pool.query(
        `UPDATE auctions SET status = 'cancelled' WHERE id = $1`,
        [auctionId],
      );
      // Return item to seller
      const item = auction.item_data;
      await pool.query(
        `INSERT INTO player_items
           (id, player_id, slot, tier, set_id, power, sell_value, name, icon_path, is_locked, is_equipped, enchantments)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, false, false, $10)
         ON CONFLICT (id, player_id) DO NOTHING`,
        [
          item.id,
          auction.seller_id,
          item.slot,
          item.tier,
          item.setId,
          item.power,
          item.sellValue,
          item.name,
          item.iconPath,
          JSON.stringify(item.enchantments ?? []),
        ],
      );
      await pool.query('COMMIT');
    } catch (e) {
      await pool.query('ROLLBACK');
      throw e;
    }

    return NextResponse.json({ success: true });
  } catch (err) {
    console.error('admin auctions DELETE error:', err);
    return NextResponse.json({ error: 'Failed to cancel auction' }, { status: 500 });
  }
}
