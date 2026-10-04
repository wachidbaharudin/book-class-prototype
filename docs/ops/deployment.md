# Deployment & Operations — Single Instance

Companion to [ENG-00 §7](../specs/ENG-00-architecture.md). One VPS runs one Docker Compose
project for one learning center. Sandbox → live is a config flip only ([XD-9](../specs/ENG-00-architecture.md#xd-9--%E2%9A%99%EF%B8%8F-config)).

## Topology

```
internet ──TLS──> caddy :443 ──┬── /            ──> web  :3000 (Next.js standalone)
                               └── /api/*       ──> api  :4000 (NestJS + in-process cron)
Midtrans  ──webhook──> caddy ──> /api/webhooks/midtrans ──> api
                                                    api ──> db :5432 (PostgreSQL 16)
                                                    db  ──> nightly pg_dump ──> off-host storage
```

Only Caddy publishes host ports. `web`, `api`, and `db` are reachable only on the Compose network.

## Files

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Production stack: `caddy`, `web`, `api`, `db` |
| `Caddyfile` | Reverse-proxy routes and automatic TLS |
| `apps/api/Dockerfile` | Multi-stage NestJS image (`node apps/api/dist/main.js`) |
| `apps/web/Dockerfile` | Multi-stage Next.js standalone image |
| `scripts/backup.sh` | `pg_dump` + optional rclone sync + local retention |
| `scripts/restore.sh` | Restore drill into a scratch database |

## Configuration

Production reads the same variable names as local dev, from a git-ignored `.env` (or the
deployment's secret store). Required:

| Variable | Notes |
|---|---|
| `DOMAIN` | Public hostname Caddy serves and requests a certificate for |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | Database bootstrap |
| `APP_ENCRYPTION_KEY` | 32-byte base64 key for `centers.midtrans_server_key_enc` |
| `MIDTRANS_CLIENT_KEY` / `MIDTRANS_SERVER_KEY` | Gateway credentials (sandbox or live) |
| `MIDTRANS_IS_PRODUCTION` | `false` = sandbox; `true` = live. The only flip. |
| `MAILER_DSN` | SMTP/API DSN consumed by the `Mailer` port |
| `BACKUP_DIR`, `BACKUP_RETENTION_DAYS`, `RCLONE_REMOTE` | Backup job settings (`RCLONE_REMOTE` optional but recommended) |

Secrets live only in the environment. The one exception is the encrypted Midtrans server key
stored per center ([ENG-00 §3](../specs/ENG-00-architecture.md#3-tech-stack)).

## First deploy

```bash
cp .env.example .env      # fill in real values, including a strong POSTGRES_PASSWORD
pnpm install              # host tooling (drizzle-kit, scripts)
node scripts/compose.mjs -f docker-compose.yml up -d --build
# apply migrations inside the api image (the db port is not published in production)
node scripts/compose.mjs -f docker-compose.yml run --rm api node apps/api/dist/db/migrate.js
```

Point Midtrans's webhook URL at `https://<DOMAIN>/api/webhooks/midtrans`. No tunnel is needed in
production; `ngrok`-style tunnels are only for local sandbox testing.

## Backup & restore drill (AC-5)

Backups run nightly from cron on the VPS:

```cron
15 3 * * *  cd /srv/book-class-prototype && BACKUP_DIR=/srv/backups RCLONE_REMOTE=r2:bookclass ./scripts/backup.sh >> /var/log/bookclass-backup.log 2>&1
```

`scripts/backup.sh` writes `postgres` custom-format dumps, optionally syncs them off-host with
rclone, and prunes local dumps older than `BACKUP_RETENTION_DAYS`. Append-only money tables make
point-in-time reasoning easy, but they are **not** a backup substitute.

### Drill runbook

Run this on staging at least once, and repeat after any schema or Compose change:

1. **Back up:** `./scripts/backup.sh` → note the printed `backups/bookclass_<ts>.dump`.
2. **Restore into scratch:** `./scripts/restore.sh backups/bookclass_<ts>.dump` — this recreates
   `${POSTGRES_DB}_restore` and never touches the live database.
3. **Verify:** the script prints the restored public table count. Compare it with the live
   database: `SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';`.
4. **Spot-check money data:** `SELECT count(*) FROM payments;` and
   `SELECT count(*) FROM refunds;` in the scratch database should be non-zero on a real center.
5. **Clean up:** drop the scratch database with the command the script prints.

**Status:** the drill was executed against the local Compose stack on 2026-10-04 — see
[restore-drill.md](restore-drill.md) for the captured run. Repeat it once on staging before go-live
(AC-5); staging does not exist yet in this repository's environments.

## Scaling story (if ever needed)

The single-instance choice is a decision, not an accident. The upgrade path is additive:

- **db** → managed PostgreSQL; keep `DATABASE_URL` and the migrations unchanged.
- **api** → N replicas behind Caddy; pin the in-process cron jobs to one replica with an env flag
  so jobs do not run N times. `@nestjs/schedule` needs no leader election at N=1 ([ENG-00 §3](../specs/ENG-00-architecture.md#3-tech-stack)).
- **web** → serve the standalone build from a CDN; it is stateless.
- **multi-center** → the schema already carries `center_id` everywhere; the upgrade is Postgres
  RLS (`SET app.center_id` per transaction) plus provisioning ([XD-8](../specs/ENG-00-architecture.md#xd-8--%F0%9F%8F%A2-center-scoping)).
