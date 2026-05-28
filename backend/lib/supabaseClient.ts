import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.SUPABASE_URL;
// Prefer service_role key for server-side API (bypasses RLS safely).
// Fall back to anon key for local dev without service_role configured.
const supabaseKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error(
    'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_ANON_KEY environment variables'
  );
}

export const supabase = createClient(supabaseUrl, supabaseKey);
