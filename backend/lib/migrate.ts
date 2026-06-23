import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { Client } from 'pg';

let migrated = false;

export async function runMigration(): Promise<void> {
  if (migrated) return;

  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.warn('[migrate] DATABASE_URL not set — skipping auto-migration.');
    return;
  }

  // Try multiple paths to find schema.sql (handles local dev and Next.js build output)
  const candidates = [
    join(process.cwd(), 'database', 'schema.sql'),
    join(process.cwd(), 'backend', 'database', 'schema.sql'),
    resolve(__dirname, '../../database/schema.sql'),
    resolve(__dirname, '../../../database/schema.sql'),
  ];

  let sql: string | null = null;
  for (const candidate of candidates) {
    try {
      sql = readFileSync(candidate, 'utf-8');
      console.log(`[migrate] Found schema.sql at: ${candidate}`);
      break;
    } catch {
      // try next candidate
    }
  }

  if (!sql) {
    console.error('[migrate] Could not find schema.sql in any of:', candidates);
    console.warn('[migrate] Skipping migration — database schema may need to be applied manually.');
    return;
  }

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
