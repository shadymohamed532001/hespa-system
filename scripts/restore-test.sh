#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/hesba-backup.dump.enc" >&2
  exit 1
fi
if [[ -z "${BACKUP_ENCRYPTION_PASSWORD:-}" ]]; then
  echo "BACKUP_ENCRYPTION_PASSWORD must be exported" >&2
  exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${HESBA_ENV_FILE:-$project_dir/.env.production}"
source_file="$1"
test_db="hesba_restore_test_$(date -u +%Y%m%d%H%M%S)"
compose=(docker compose --env-file "$env_file" -f "$project_dir/docker-compose.prod.yml")

cleanup() {
  "${compose[@]}" exec -T postgres sh -c \
    'dropdb -U "$POSTGRES_USER" --if-exists "$1"' _ "$test_db" >/dev/null
}
trap cleanup EXIT

"${compose[@]}" exec -T postgres sh -c \
  'createdb -U "$POSTGRES_USER" "$1"' _ "$test_db"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -pass env:BACKUP_ENCRYPTION_PASSWORD -in "$source_file" |
  "${compose[@]}" exec -T postgres sh -c \
    'pg_restore -U "$POSTGRES_USER" -d "$1" --no-owner --exit-on-error' _ "$test_db"
"${compose[@]}" exec -T postgres sh -c \
  'psql -U "$POSTGRES_USER" -d "$1" -v ON_ERROR_STOP=1 -c "SELECT count(*) AS users FROM users"' _ "$test_db"
echo "Restore test succeeded: $test_db"
