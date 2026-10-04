#!/usr/bin/env bash
# Nightly logical backup of the production Postgres container (ENG-00 §7, AC-5).
#
#   scripts/backup.sh
#
# Writes a custom-format dump under $BACKUP_DIR and, when $RCLONE_REMOTE is set,
# copies it to off-host storage (rclone remote:path) before pruning old local
# dumps. Intended to run from cron on the VPS; see docs/ops/deployment.md.
set -euo pipefail

cd "$(dirname "$0")/.."

BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE=(docker-compose)
else
  echo "error: need 'docker compose' or 'docker-compose' on PATH" >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a; [ -f .env ] && . ./.env; set +a
: "${POSTGRES_USER:=bookclass}"
: "${POSTGRES_DB:=bookclass}"

mkdir -p "$BACKUP_DIR"
DUMP_FILE="$BACKUP_DIR/${POSTGRES_DB}_${TIMESTAMP}.dump"

echo "==> dumping ${POSTGRES_DB} to ${DUMP_FILE}"
"${COMPOSE[@]}" -f docker-compose.yml exec -T db \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  --format=custom --no-owner --no-acl > "$DUMP_FILE"

echo "==> wrote $(du -h "$DUMP_FILE" | cut -f1)"

if [ -n "${RCLONE_REMOTE:-}" ]; then
  echo "==> syncing to ${RCLONE_REMOTE}"
  rclone copy "$DUMP_FILE" "${RCLONE_REMOTE}"
else
  echo "!! RCLONE_REMOTE not set — dump is local only. Configure off-host sync."
fi

echo "==> pruning local dumps older than ${RETENTION_DAYS} days"
find "$BACKUP_DIR" -name "${POSTGRES_DB}_*.dump" -type f -mtime "+${RETENTION_DAYS}" -delete

echo "==> backup complete: ${DUMP_FILE}"
