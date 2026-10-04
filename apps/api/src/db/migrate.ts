import { join } from 'node:path';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { Pool } from 'pg';

/**
 * Apply generated migrations from the `drizzle/` folder. Run in the deploy
 * pipeline or as a one-off container before starting the API:
 *   node apps/api/dist/db/migrate.js
 */
async function main(): Promise<void> {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is required to run migrations');
  }

  const pool = new Pool({ connectionString });
  try {
    await migrate(drizzle(pool), {
      migrationsFolder: join(__dirname, '..', '..', 'drizzle'),
    });
    console.log('migrations applied');
  } finally {
    await pool.end();
  }
}

main().catch((error: unknown) => {
  console.error('migration failed', error);
  process.exit(1);
});
