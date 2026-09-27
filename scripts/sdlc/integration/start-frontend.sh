#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npx

DIST_VALUE="${FRONTEND_DIST:-$(config_value "$CONFIG" artifacts frontend_dist || true)}"
MANIFEST_VALUE="$(config_value "$CONFIG" artifacts frontend_manifest || true)"
HOST="${FRONTEND_HOST:-$(config_value "$CONFIG" services frontend_host || true)}"
PORT="${FRONTEND_PORT:-$(config_value "$CONFIG" services frontend_port || true)}"
[[ -n "$DIST_VALUE" && -n "$MANIFEST_VALUE" && -n "$HOST" && -n "$PORT" ]] || { echo "Error: frontend artifact/manifest/host/port are not configured" >&2; exit 10; }
DIST="$(normalize_path "$DIST_VALUE")"
MANIFEST="$(normalize_path "$MANIFEST_VALUE")"
[[ -f "$DIST/index.html" ]] || { echo "Error: frontend dist not found: $DIST" >&2; exit 60; }
[[ -f "$MANIFEST" ]] || { echo "Error: frontend manifest not found: $MANIFEST" >&2; exit 60; }
mkdir -p "$ARTIFACTS/runtime"
(cd "$DIST" && npx --yes http-server . -a "$HOST" -p "$PORT") > "$ARTIFACTS/runtime/frontend.log" 2>&1 &
echo "$!" > "$ARTIFACTS/runtime/frontend.pid"
echo "Started frontend PID $(cat "$ARTIFACTS/runtime/frontend.pid") at $HOST:$PORT"
