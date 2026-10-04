#!/usr/bin/env bash
# Restore drill for the production database (ENG-00 §7, AC-5).
#
#   scripts/restore.sh <dump-file> [target-db]
#
# Restores a custom-format dump into a SCRATCH database (default
# `${POSTGRES_DB}_restore`) so the drill never touches production data, then runs
# a smoke query. Full runbook: docs/ops/deployment.md.
set -euo pipefail

cd "$(dirname "$0")/.."

DUMP_FILE="${1:?usage: scripts/restore.sh <dump-file> [target-db]}"
[ -f "$DUMP_FILE" ] || { echo "error: dump not found: $DUMP_FILE" >&2; exit 1; }

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
TARGET_DB="${2:-${POSTGRES_DB}_restore}"

echo "==> recreating scratch database ${TARGET_DB}"
"${COMPOSE[@]}" -f docker-compose.yml exec -T db \
  psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"${TARGET_DB}\";" \
  -c "CREATE DATABASE \"${TARGET_DB}\";"

echo "==> restoring ${DUMP_FILE} into ${TARGET_DB}"
"${COMPOSE[@]}" -f docker-compose.yml exec -T db \
  pg_restore -U "$POSTGRES_USER" -d "$TARGET_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"

echo "==> smoke check (table count in ${TARGET_DB})"
"${COMPOSE[@]}" -f docker-compose.yml exec -T db \
  psql -U "$POSTGRES_USER" -d "$TARGET_DB" -tAc \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';"

echo "==> restore drill complete. Drop the scratch db when done:"
echo "    ${COMPOSE[*]} -f docker-compose.yml exec db psql -U ${POSTGRES_USER} -d postgres -c 'DROP DATABASE ${TARGET_DB};'"
