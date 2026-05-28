export async function register() {
  // Only run migration on the Node.js server runtime, not in the Edge runtime.
  if (process.env.NEXT_RUNTIME === 'nodejs') {
    const { runMigration } = await import('./lib/migrate');
    await runMigration();
  }
}
