#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command npx
DIST="${FRONTEND_DIST:-$REPO_ROOT/artifacts/angular/dist/browser}"
PORT="${FRONTEND_PORT:-4300}"
[[ -f "$DIST/index.html" ]] || { echo "Error: frontend dist not found: $DIST" >&2; exit 60; }
mkdir -p "$ARTIFACTS/runtime"
(cd "$DIST" && npx --yes http-server . -a 127.0.0.1 -p "$PORT") > "$ARTIFACTS/runtime/frontend.log" 2>&1 &
echo "$!" > "$ARTIFACTS/runtime/frontend.pid"
echo "Started frontend PID $(cat "$ARTIFACTS/runtime/frontend.pid") on port $PORT"
