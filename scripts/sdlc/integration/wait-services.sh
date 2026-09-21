#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command curl
BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:18080/actuator/health}"
FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:4300/}"
TIMEOUT="${STARTUP_TIMEOUT_SECONDS:-90}"
wait_url() {
  local url="$1" label="$2" started now
  started="$(date +%s)"
  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$label ready: $url"
      return 0
    fi
    now="$(date +%s)"
    (( now - started >= TIMEOUT )) && {
      echo "Error: timeout waiting for $label: $url" >&2
      return 50
    }
    sleep 2
  done
}
wait_url "$BACKEND_URL" backend
wait_url "$FRONTEND_URL" frontend
