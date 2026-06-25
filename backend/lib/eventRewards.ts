import { Pool } from 'pg';

type RankRewardRow = {
  rank_from: number;
  rank_to: number;
  reward_type: 'gold' | 'item';
  amount: number | null;
  item_id: string | null;
  leaderboard_type: 'solo' | 'clan';
};

type WinnerRow = {
  player_id: string;
  rank: number;
};

async function getWinnersForReward(
  pool: Pool,
  eventId: string,
  reward: RankRewardRow,
): Promise<WinnerRow[]> {
  if (reward.leaderboard_type === 'clan') {
    const { rows } = await pool.query<WinnerRow>(
      `WITH ranked_clans AS (
         SELECT
           ecs.clan_id,
           RANK() OVER (ORDER BY ecs.score DESC) AS rank
         FROM event_clan_scores ecs
         WHERE ecs.event_id = $1
       )
       SELECT p.id AS player_id, rc.rank
       FROM ranked_clans rc
       JOIN players p ON p.clan_id = rc.clan_id
       WHERE rc.rank BETWEEN $2 AND $3`,
      [eventId, reward.rank_from, reward.rank_to],
    );
    return rows;
  }

  const { rows } = await pool.query<WinnerRow>(
    `WITH ranked_players AS (
       SELECT
         eps.player_id,
         RANK() OVER (ORDER BY eps.score DESC) AS rank
       FROM event_player_scores eps
       WHERE eps.event_id = $1
     )
     SELECT player_id, rank
     FROM ranked_players
     WHERE rank BETWEEN $2 AND $3`,
    [eventId, reward.rank_from, reward.rank_to],
  );
  return rows;
}

async function grantRewardIfNotDistributed(
  pool: Pool,
  eventId: string,
  winner: WinnerRow,
  reward: RankRewardRow,
): Promise<boolean> {
  const amount = reward.reward_type === 'gold' ? reward.amount : null;
  const itemId = reward.reward_type === 'item' ? reward.item_id : null;

  const { rowCount } = await pool.query(
    `WITH new_distribution AS (
       INSERT INTO event_rewards_distributed (event_id, player_id, rank)
       VALUES ($1, $2, $3)
       ON CONFLICT (event_id, player_id) DO NOTHING
       RETURNING player_id
     )
     INSERT INTO pending_rewards (player_id, reward_type, amount, item_id, given_by)
     SELECT $2, $4, $5, $6, NULL
     FROM new_distribution`,
    [eventId, winner.player_id, winner.rank, reward.reward_type, amount, itemId],
  );

  return (rowCount ?? 0) > 0;
}

async function distributeRewardsForEvent(pool: Pool, eventId: string): Promise<number> {
  const { rows: rewards } = await pool.query<RankRewardRow>(
    `SELECT rank_from, rank_to, reward_type, amount, item_id, leaderboard_type
     FROM event_rank_rewards
     WHERE event_id = $1
     ORDER BY rank_from ASC, rank_to ASC`,
    [eventId],
  );

  if (rewards.length === 0) return 0;

  let distributedCount = 0;

  for (const reward of rewards) {
    const winners = await getWinnersForReward(pool, eventId, reward);
    for (const winner of winners) {
      const inserted = await grantRewardIfNotDistributed(pool, eventId, winner, reward);
      if (inserted) distributedCount += 1;
    }
  }

  return distributedCount;
}

export async function distributeExpiredEventRankRewards(pool: Pool): Promise<number> {
  const { rows: expiredEvents } = await pool.query<{ id: string }>(
    `SELECT id FROM seasonal_events WHERE ends_at <= NOW()`,
  );

  let totalDistributed = 0;
  for (const event of expiredEvents) {
    totalDistributed += await distributeRewardsForEvent(pool, event.id);
  }

  return totalDistributed;
}
