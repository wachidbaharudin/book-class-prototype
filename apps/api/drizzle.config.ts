import { config } from 'dotenv';
import { defineConfig } from 'drizzle-kit';

// Load the repo-root .env when running drizzle-kit from apps/api. In CI/prod the
// variable is already in the environment and this is a no-op.
config({ path: '../../.env' });

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL ?? 'postgresql://bookclass:change-me@localhost:5433/bookclass',
  },
  strict: true,
  verbose: true,
});
