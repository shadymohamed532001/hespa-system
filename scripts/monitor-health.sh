#!/usr/bin/env bash
set -Eeuo pipefail

health_url="${HESBA_HEALTH_URL:-http://127.0.0.1:3000/api/health}"
response="$(curl --fail --silent --show-error --max-time 10 "$health_url")"
if [[ "$response" != *'"status":"ok"'* ]]; then
  echo "Unhealthy response from $health_url: $response" >&2
  exit 1
fi
echo "$response"
