import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const MARKET_FEE_PCT = 0.05;

// GET /api/auction/[id] — get auction details with bid history
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { id } = await params;

  try {
    const { rows } = await pool.query(
      `SELECT a.*, p.username AS seller_name, hb.username AS highest_bidder_name
       FROM auctions a
       JOIN players p ON p.id = a.seller_id
       LEFT JOIN players hb ON hb.id = a.highest_bidder_id
       WHERE a.id = $1`,
      [id],
    );
    if (rows.length === 0) {
      return NextResponse.json({ error: 'Auction not found' }, { status: 404 });
    }
    const a = rows[0];

    const { rows: bids } = await pool.query(
      `SELECT ab.amount, ab.placed_at, p.username AS bidder_name
       FROM auction_bids ab
       JOIN players p ON p.id = ab.bidder_id
       WHERE ab.auction_id = $1
       ORDER BY ab.amount DESC
       LIMIT 20`,
      [id],
    );

    return NextResponse.json({
      auction: {
        id: a.id,
        sellerId: a.seller_id,
        sellerName: a.seller_name,
        item: a.item_data,
        minPrice: a.min_price,
        buyNowPrice: a.buy_now_price,
        currentBid: a.current_bid,
        highestBidderId: a.highest_bidder_id,
        highestBidderName: a.highest_bidder_name,
        claimed: a.claimed,
        endsAt: a.ends_at,
        status: a.status,
        createdAt: a.created_at,
        isOwner: a.seller_id === auth.playerId,
        isWinner:
          a.highest_bidder_id === auth.playerId &&
          (a.status === 'sold' || (a.status === 'active' && new Date(a.ends_at) <= new Date())),
      },
      bids: bids.map((b) => ({
        amount: b.amount,
        bidderName: b.bidder_name,
        placedAt: b.placed_at,
      })),
      marketFeePct: MARKET_FEE_PCT,
    });
  } catch (err) {
    console.error('auction/[id] GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch auction' }, { status: 500 });
  }
}

// POST /api/auction/[id] — bid, buy now, cancel, or claim
// Body: { action: 'bid'|'buy_now'|'cancel'|'claim', amount?: number }
export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  const { id } = await params;

  let body: { action?: string; amount?: number };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { action, amount } = body;
  if (!action) return NextResponse.json({ error: 'action is required' }, { status: 400 });

  try {
    const { rows } = await pool.query(
      `SELECT * FROM auctions WHERE id = $1`,
      [id],
    );
    if (rows.length === 0) {
      return NextResponse.json({ error: 'Auction not found' }, { status: 404 });
    }
    const auction = rows[0];

    // --- BID ---
    if (action === 'bid') {
      if (auction.status !== 'active' || new Date(auction.ends_at) <= new Date()) {
        return NextResponse.json({ error: 'Auction is not active' }, { status: 409 });
      }
      if (auction.seller_id === auth.playerId) {
        return NextResponse.json({ error: 'Cannot bid on your own auction' }, { status: 403 });
      }
      const bidAmount = Math.floor(amount ?? 0);
      const minBid = Math.max(auction.min_price, auction.current_bid + 1);
      if (bidAmount < minBid) {
        return NextResponse.json(
          { error: `Minimum bid is ${minBid}` },
          { status: 400 },
        );
      }
      if (auction.buy_now_price && bidAmount >= auction.buy_now_price) {
        return NextResponse.json(
          { error: 'Use buy_now action to purchase at buy-now price' },
          { status: 400 },
        );
      }

      await pool.query('BEGIN');
      try {
        await pool.query(
          `UPDATE auctions SET current_bid = $1, highest_bidder_id = $2 WHERE id = $3`,
          [bidAmount, auth.playerId, id],
        );
        await pool.query(
          `INSERT INTO auction_bids (auction_id, bidder_id, amount) VALUES ($1, $2, $3)`,
          [id, auth.playerId, bidAmount],
        );
        await pool.query('COMMIT');
      } catch (e) {
        await pool.query('ROLLBACK');
        throw e;
      }

      return NextResponse.json({ success: true, newBid: bidAmount });
    }

    // --- BUY NOW ---
    if (action === 'buy_now') {
      if (!auction.buy_now_price) {
        return NextResponse.json({ error: 'No buy-now price set' }, { status: 400 });
      }
      if (auction.status !== 'active' || new Date(auction.ends_at) <= new Date()) {
        return NextResponse.json({ error: 'Auction is not active' }, { status: 409 });
      }
      if (auction.seller_id === auth.playerId) {
        return NextResponse.json({ error: 'Cannot buy your own auction' }, { status: 403 });
      }

      await pool.query('BEGIN');
      try {
        // Mark auction sold
        await pool.query(
          `UPDATE auctions
           SET status = 'sold', current_bid = $1, highest_bidder_id = $2
           WHERE id = $3 AND status = 'active'`,
          [auction.buy_now_price, auth.playerId, id],
        );

        // Transfer item to buyer's inventory
        const item = auction.item_data;
        await pool.query(
          `INSERT INTO player_items
             (id, player_id, slot, tier, set_id, power, sell_value, name, icon_path, is_locked, is_equipped, enchantments)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, false, false, $10)
           ON CONFLICT (id, player_id) DO NOTHING`,
          [
            item.id,
            auth.playerId,
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

        // Pay seller (minus fee) via pending_rewards
        const sellerGold = Math.floor(auction.buy_now_price * (1 - MARKET_FEE_PCT));
        await pool.query(
          `INSERT INTO pending_rewards (player_id, reward_type, amount, given_by)
           VALUES ($1, 'gold', $2, $1)`,
          [auction.seller_id, sellerGold],
        );

        // Mark as claimed for buyer
        await pool.query(`UPDATE auctions SET claimed = true WHERE id = $1`, [id]);

        await pool.query('COMMIT');
      } catch (e) {
        await pool.query('ROLLBACK');
        throw e;
      }

      return NextResponse.json({
        success: true,
        goldPaid: auction.buy_now_price,
        item: auction.item_data,
      });
    }

    // --- CLAIM (winner claims item after auction ends) ---
    if (action === 'claim') {
      if (auction.claimed) {
        return NextResponse.json({ error: 'Already claimed' }, { status: 409 });
      }

      const isExpiredWithWinner =
        auction.status === 'active' &&
        new Date(auction.ends_at) <= new Date() &&
        auction.highest_bidder_id;

      const isSold = auction.status === 'sold';

      if (!isExpiredWithWinner && !isSold) {
        return NextResponse.json({ error: 'Auction cannot be claimed yet' }, { status: 409 });
      }
      if (auction.highest_bidder_id !== auth.playerId) {
        return NextResponse.json({ error: 'You are not the winner' }, { status: 403 });
      }

      await pool.query('BEGIN');
      try {
        // Mark auction as sold + claimed
        await pool.query(
          `UPDATE auctions SET status = 'sold', claimed = true WHERE id = $1`,
          [id],
        );

        // Transfer item to winner's inventory
        const item = auction.item_data;
        await pool.query(
          `INSERT INTO player_items
             (id, player_id, slot, tier, set_id, power, sell_value, name, icon_path, is_locked, is_equipped, enchantments)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, false, false, $10)
           ON CONFLICT (id, player_id) DO NOTHING`,
          [
            item.id,
            auth.playerId,
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

        // Pay seller (minus fee) via pending_rewards
        const sellerGold = Math.floor(auction.current_bid * (1 - MARKET_FEE_PCT));
        await pool.query(
          `INSERT INTO pending_rewards (player_id, reward_type, amount, given_by)
           VALUES ($1, 'gold', $2, $1)`,
          [auction.seller_id, sellerGold],
        );

        await pool.query('COMMIT');
      } catch (e) {
        await pool.query('ROLLBACK');
        throw e;
      }

      return NextResponse.json({
        success: true,
        goldPaid: auction.current_bid,
        item: auction.item_data,
      });
    }

    // --- CANCEL ---
    if (action === 'cancel') {
      if (auction.seller_id !== auth.playerId) {
        return NextResponse.json({ error: 'Only the seller can cancel' }, { status: 403 });
      }
      if (auction.status !== 'active') {
        return NextResponse.json({ error: 'Auction is not active' }, { status: 409 });
      }
      if (auction.highest_bidder_id) {
        return NextResponse.json(
          { error: 'Cannot cancel an auction that already has bids' },
          { status: 409 },
        );
      }

      await pool.query('BEGIN');
      try {
        await pool.query(
          `UPDATE auctions SET status = 'cancelled' WHERE id = $1`,
          [id],
        );
        // Return item to seller's inventory
        const item = auction.item_data;
        await pool.query(
          `INSERT INTO player_items
             (id, player_id, slot, tier, set_id, power, sell_value, name, icon_path, is_locked, is_equipped, enchantments)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, false, false, $10)
           ON CONFLICT (id, player_id) DO NOTHING`,
          [
            item.id,
            auth.playerId,
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

      return NextResponse.json({ success: true, itemReturned: true });
    }

    return NextResponse.json({ error: 'Unknown action' }, { status: 400 });
  } catch (err) {
    console.error('auction/[id] POST error:', err);
    return NextResponse.json({ error: 'Failed to process action' }, { status: 500 });
  }
}
