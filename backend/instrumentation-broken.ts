export async function register() {
  // Only run migration on the Node.js server runtime, not in the Edge runtime.
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    // Set environment variables for Cloud Run
    process.env.CLOUD_SQL_CONNECTION_NAME = process.env.CLOUD_SQL_CONNECTION_NAME || 'astral-theory-449511-c1:europe-west3:idle-forge-pg';
    process.env.DB_USER = process.env.DB_USER || 'idle_forge_app';
    process.env.DB_NAME = process.env.DB_NAME || 'idle_forge';

    // Initialize database connection pool
    const { initializePool } = await import('./lib/dbClient');
    await initializePool();

    // Run migrations
    const { runMigration } = await import('./lib/migrate');
    await runMigration();
  }
}
