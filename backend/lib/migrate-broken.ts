import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { Client } from 'pg';

let migrated = false;

export async function runMigration(): Promise<void> {
  if (migrated) return;

<<<<<<< HEAD
  // Try to find schema.sql file
=======
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    console.warn('[migrate] DATABASE_URL not set — skipping auto-migration.');
    return;
  }

  // Try multiple paths to find schema.sql (handles local dev and Next.js build output)
>>>>>>> c74c4876a1f43ff0ed2c426087b772c82eb2698c
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

  // Determine connection method
  let connectionConfig: any;
  const cloudSqlConnectionName = process.env.CLOUD_SQL_CONNECTION_NAME;
  const databaseUrl = process.env.DATABASE_URL;

  if (cloudSqlConnectionName) {
    // Cloud Run with Cloud SQL Connector
    try {
      const { Connector } = await import('@google-cloud/sql-connector');
      const connector = new Connector();
      const clientOpts = await connector.getConnection({
        instanceConnectionString: cloudSqlConnectionName,
      });
      connectionConfig = {
        ...clientOpts,
        user: process.env.DB_USER || 'idle_forge_app',
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME || 'idle_forge',
      };
    } catch (err) {
      console.error('[migrate] Cloud SQL Connector initialization failed:', err);
      throw err;
    }
  } else if (databaseUrl) {
    // Local development with DATABASE_URL
    connectionConfig = { connectionString: databaseUrl };
  } else {
    console.warn('[migrate] Neither CLOUD_SQL_CONNECTION_NAME nor DATABASE_URL set — skipping auto-migration.');
    return;
  }

  const client = new Client(connectionConfig);
  try {
    await client.connect();
    console.log('[migrate] Connected to database, applying schema...');
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
