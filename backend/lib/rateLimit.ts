/**
 * Simple in-memory rate limiter: max 30 requests per minute per IP.
 * Resets the window every 60 seconds.
 */

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

const store = new Map<string, RateLimitEntry>();
const MAX_REQUESTS = 30;
const WINDOW_MS = 60 * 1000;
const SWEEP_INTERVAL_MS = 5 * 60 * 1000;

let lastSweepAt = 0;

function cleanupExpiredEntries(now: number) {
  if (now - lastSweepAt < SWEEP_INTERVAL_MS) return;
  lastSweepAt = now;

  store.forEach((entry, ip) => {
    if (now > entry.resetAt) {
      store.delete(ip);
    }
  });
}

export function checkRateLimit(ip: string): { allowed: boolean; remaining: number } {
  const now = Date.now();
  cleanupExpiredEntries(now);

  const entry = store.get(ip);

  if (!entry || now > entry.resetAt) {
    store.set(ip, { count: 1, resetAt: now + WINDOW_MS });
    return { allowed: true, remaining: MAX_REQUESTS - 1 };
  }

  entry.count += 1;
  if (entry.count > MAX_REQUESTS) {
    return { allowed: false, remaining: 0 };
  }

  return { allowed: true, remaining: MAX_REQUESTS - entry.count };
}

export function getClientIp(request: Request): string {
  const forwardedFor = request.headers.get('x-forwarded-for');
  if (forwardedFor) {
    const candidate = forwardedFor
      .split(',')
      .map((ip) => ip.trim())
      .find((ip) => ip.length > 0);
    if (candidate) return candidate;
  }

  const fallbackHeaders = [
    'x-real-ip',
    'x-client-ip',
    'x-forwarded',
    'x-cluster-client-ip',
    'x-vercel-forwarded-for',
  ];

  for (const header of fallbackHeaders) {
    const value = request.headers.get(header)?.trim();
    if (value) return value;
  }

  return 'unknown';
}
