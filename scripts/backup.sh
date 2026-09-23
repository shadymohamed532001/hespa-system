#!/usr/bin/env bash
set -Eeuo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${HESBA_ENV_FILE:-$project_dir/.env.production}"
backup_dir="${HESBA_BACKUP_DIR:-$project_dir/backups}"

if [[ -z "${BACKUP_ENCRYPTION_PASSWORD:-}" ]]; then
  echo "BACKUP_ENCRYPTION_PASSWORD must be exported" >&2
  exit 1
fi
if [[ ! -f "$env_file" ]]; then
  echo "Environment file not found: $env_file" >&2
  exit 1
fi

mkdir -p "$backup_dir"
umask 077
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
target="$backup_dir/hesba-$timestamp.dump.enc"

docker compose --env-file "$env_file" -f "$project_dir/docker-compose.prod.yml" \
  exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner' |
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 \
    -pass env:BACKUP_ENCRYPTION_PASSWORD -out "$target"

openssl dgst -sha256 "$target" >"$target.sha256"
find "$backup_dir" -type f -name 'hesba-*.dump.enc*' -mtime +"${BACKUP_RETENTION_DAYS:-30}" -delete
echo "$target"
