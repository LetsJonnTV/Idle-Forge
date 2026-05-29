import jwt from 'jsonwebtoken';

export interface JwtPayload {
  playerId: string;
  username: string;
  isAdmin: boolean;
  iat?: number;
  exp?: number;
}

function getJwtSecret(): string | null {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.trim().length === 0) {
    console.error('JWT_SECRET is not configured');
    return null;
  }
  return secret;
}

/**
 * Verifies a JWT Bearer token from the Authorization header.
 * Returns the decoded payload or null if invalid/expired.
 */
export async function verifyJwt(token: string): Promise<JwtPayload | null> {
  const secret = getJwtSecret();
  if (!secret) {
    return null;
  }
  try {
    const payload = jwt.verify(token, secret) as JwtPayload;
    return payload;
  } catch {
    return null;
  }
}

/**
 * Signs a new JWT for the given player.
 */
export function signJwt(payload: Omit<JwtPayload, 'iat' | 'exp'>): string {
  const secret = getJwtSecret();
  if (!secret) {
    throw new Error('JWT signing unavailable: missing JWT_SECRET');
  }
  return jwt.sign(payload, secret, { expiresIn: '30d' });
}

/**
 * Extracts and verifies the Bearer token from a Request.
 * Returns the payload or null.
 */
export async function getAuthPayload(request: Request): Promise<JwtPayload | null> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  const token = authHeader.slice(7).trim();
  return verifyJwt(token);
}
