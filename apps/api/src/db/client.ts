import { drizzle, type NodePgDatabase } from 'drizzle-orm/node-postgres';
import { Pool } from 'pg';
import * as schema from './schema';

export type Database = NodePgDatabase<typeof schema>;

/** Create a Drizzle client for a connection string (migrations, scripts, tests). */
export function createDb(connectionString: string): Database {
  const pool = new Pool({ connectionString });
  return drizzle(pool, { schema });
}

let cached: Database | undefined;

/**
 * Lazily create the process-wide client from `DATABASE_URL`. Env validation and
 * center scoping are layered on top by the config/center-context modules
 * (ENG-00-06/07); this stays a plain client.
 */
export function getDb(): Database {
  if (!cached) {
    const connectionString = process.env.DATABASE_URL;
    if (!connectionString) {
      throw new Error('DATABASE_URL is required');
    }
    cached = createDb(connectionString);
  }
  return cached;
}
