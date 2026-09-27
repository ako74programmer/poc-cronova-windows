#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command curl
BACKEND_URL="${BACKEND_URL:-$(config_value "$CONFIG" services backend_health_url || true)}"
FRONTEND_URL="${FRONTEND_URL:-$(config_value "$CONFIG" services frontend_url || true)}"
TIMEOUT="${STARTUP_TIMEOUT_SECONDS:-$(config_value "$CONFIG" services startup_timeout_seconds || true)}"
TIMEOUT="${TIMEOUT:-90}"
[[ -n "$BACKEND_URL" && -n "$FRONTEND_URL" ]] || { echo "Error: service readiness URLs are not configured" >&2; exit 10; }
wait_url() {
  local url="$1" label="$2" started now
  started="$(date +%s)"
  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      echo "$label ready: $url"
      return 0
    fi
    now="$(date +%s)"
    if (( now - started >= TIMEOUT )); then
      echo "Error: timeout waiting for $label: $url" >&2
      return 50
    fi
    sleep 2
  done
}
wait_url "$BACKEND_URL" backend
wait_url "$FRONTEND_URL" frontend
