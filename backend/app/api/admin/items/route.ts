import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabaseClient';
import { checkRateLimit, getClientIp } from '@/lib/rateLimit';
import { requireAdmin } from '@/lib/adminAuth';

// GET /api/admin/items — admin only, returns ALL items (including inactive)
export async function GET(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  const url = new URL(request.url);
  const search = url.searchParams.get('q')?.trim() ?? '';
  const slot = url.searchParams.get('slot')?.trim() ?? '';

  let query = supabase
    .from('item_blueprints')
    .select('id, slot, name, base_power, icon_path, is_active, created_at')
    .order('slot')
    .order('id');

  if (search) query = query.ilike('name', `%${search}%`);
  if (slot) query = query.eq('slot', slot);

  const { data: items, error } = await query;
  if (error) {
    console.error('Admin fetch items error:', error);
    return NextResponse.json({ error: 'Failed to fetch items' }, { status: 500 });
  }

  return NextResponse.json({ items: items ?? [] });
}

// POST /api/admin/items — admin only, create new item blueprint
export async function POST(request: NextRequest) {
  const ip = getClientIp(request);
  const { allowed } = checkRateLimit(ip);
  if (!allowed) return NextResponse.json({ error: 'Too many requests' }, { status: 429 });

  const { error: authError, auth } = await requireAdmin(request);
  if (authError || !auth) return authError!;

  let body: { id?: string; slot?: string; name?: string; base_power?: number; icon_path?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON' }, { status: 400 });
  }

  const { id, slot, name, base_power, icon_path } = body;
  if (!id || !slot || !name || base_power === undefined) {
    return NextResponse.json({ error: 'id, slot, name and base_power are required' }, { status: 400 });
  }

  const validSlots = ['weapon', 'armor', 'helm', 'gloves', 'boots', 'ring'];
  if (!validSlots.includes(slot)) {
    return NextResponse.json({ error: `slot must be one of: ${validSlots.join(', ')}` }, { status: 400 });
  }

  const { data: item, error } = await supabase
    .from('item_blueprints')
    .insert({ id, slot, name, base_power, icon_path: icon_path ?? null })
    .select()
    .single();

  if (error) {
    console.error('Admin create item error:', error);
    return NextResponse.json({ error: 'Failed to create item', detail: error.message }, { status: 500 });
  }

  return NextResponse.json({ item }, { status: 201 });
}
