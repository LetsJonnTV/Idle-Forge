import { NextRequest, NextResponse } from 'next/server';
import { getAuthPayload } from '@/lib/auth';

/**
 * Verifies the JWT and checks isAdmin flag.
 * Returns the auth payload or sends a 401/403 response.
 */
export async function requireAdmin(request: NextRequest) {
  const auth = await getAuthPayload(request);
  if (!auth) {
    return { error: NextResponse.json({ error: 'Unauthorized' }, { status: 401 }), auth: null };
  }
  if (!auth.isAdmin) {
    return { error: NextResponse.json({ error: 'Forbidden' }, { status: 403 }), auth: null };
  }
  return { error: null, auth };
}
