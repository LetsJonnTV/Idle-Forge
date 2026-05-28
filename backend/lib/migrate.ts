import { readFileSync } from 'fs';
import { join } from 'path';
import { Client } from 'pg';

let migrated = false;

export async function runMigration(): Promise<void> {
  if (migrated) return;

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.warn('[migrate] DATABASE_URL not set — skipping auto-migration.');
    return;
  }

  const schemaPath = join(process.cwd(), 'supabase', 'schema.sql');
  const sql = readFileSync(schemaPath, 'utf-8');

  const client = new Client({ connectionString: databaseUrl });
  try {
    await client.connect();
    await client.query(sql);
    migrated = true;
    console.log('[migrate] Schema migration applied successfully.');
  } catch (err) {
    console.error('[migrate] Migration failed:', err);
    throw err;
  } finally {
    await client.end();
  }
}
