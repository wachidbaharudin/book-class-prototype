# Restore Drill — Run Log

Executed as part of [ENG-00-03 / AC-5](../specs/ENG-00-architecture.md#10-acceptance-criteria). The
same scripts run against staging before go-live; this record captures the drill mechanics being
exercised end-to-end.

## Run 1 — local Compose stack, 2026-10-04

Environment: `docker-compose.dev.yml` (`db` = PostgreSQL 16), database `bookclass`, schema applied
via the Drizzle baseline migration.

| Step | Command | Result |
|---|---|---|
| Seed | insert one `centers` row + one `users` row | `INSERT 0 1` ×2 |
| Backup | `COMPOSE_FILE=docker-compose.dev.yml BACKUP_DIR=/tmp/bookclass-backups ./scripts/backup.sh` | dump `bookclass_20261004T190804Z.dump`, 84K |
| Restore | `COMPOSE_FILE=docker-compose.dev.yml ./scripts/restore.sh <dump>` | scratch `bookclass_restore` created, `pg_restore` exit 0 |
| Verify | `SELECT count(*) ...` in scratch | 20 tables, 1 center, 1 user; money tables empty as expected |
| Cleanup | `DROP DATABASE bookclass_restore` | removed |

Observation: `scripts/restore.sh` restores into a scratch database and refuses to target the live
`POSTGRES_DB` name, so a drill cannot overwrite production data.

## Staging checklist (still open)

1. Run `scripts/backup.sh` on staging with `RCLONE_REMOTE` configured; confirm the object exists
   off-host.
2. Run `scripts/restore.sh <dump>` on staging and record the table count and a money spot-check in
   this file.
3. Confirm the nightly cron entry and that local retention prunes as configured.
