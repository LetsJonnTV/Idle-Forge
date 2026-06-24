import { NextRequest, NextResponse } from 'next/server';
import { Pool } from 'pg';
import { getAuthPayload } from '@/lib/auth';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// GET /api/auction/mine — seller's own active/past auctions + auctions the player has won
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const auth = await getAuthPayload(request);
  if (!auth) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });

  try {
    // Expire zero-bid auctions that have ended (cleanup)
    await pool.query(
      `UPDATE auctions SET status = 'expired'
       WHERE status = 'active' AND ends_at <= NOW() AND highest_bidder_id IS NULL`,
    );

    // My listings
    const { rows: selling } = await pool.query(
      `SELECT a.id, a.item_data, a.min_price, a.buy_now_price,
              a.current_bid, a.highest_bidder_id,
              hb.username AS highest_bidder_name,
              a.claimed, a.ends_at, a.status, a.created_at
       FROM auctions a
       LEFT JOIN players hb ON hb.id = a.highest_bidder_id
       WHERE a.seller_id = $1
       ORDER BY a.created_at DESC
       LIMIT 30`,
      [auth.playerId],
    );

    // Auctions I've won (highest bidder, not yet claimed)
    const { rows: won } = await pool.query(
      `SELECT a.id, a.item_data, a.min_price, a.buy_now_price,
              a.current_bid, a.seller_id,
              p.username AS seller_name,
              a.claimed, a.ends_at, a.status, a.created_at
       FROM auctions a
       JOIN players p ON p.id = a.seller_id
       WHERE a.highest_bidder_id = $1
         AND (
           (a.status = 'active' AND a.ends_at <= NOW())
           OR a.status = 'sold'
         )
         AND a.claimed = false
       ORDER BY a.ends_at DESC
       LIMIT 20`,
      [auth.playerId],
    );

    return NextResponse.json({
      selling: selling.map((a) => ({
        id: a.id,
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
      })),
      won: won.map((a) => ({
        id: a.id,
        item: a.item_data,
        finalPrice: a.current_bid,
        sellerId: a.seller_id,
        sellerName: a.seller_name,
        claimed: a.claimed,
        endsAt: a.ends_at,
        status: a.status,
      })),
    });
  } catch (err) {
    console.error('auction/mine GET error:', err);
    return NextResponse.json({ error: 'Failed to fetch auctions' }, { status: 500 });
  }
}
