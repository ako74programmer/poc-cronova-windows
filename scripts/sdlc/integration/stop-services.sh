#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
stop_pid_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local pid
  pid="$(cat "$file")"
  [[ "$pid" =~ ^[0-9]+$ ]] || { rm -f "$file"; return 0; }
  if command -v taskkill.exe >/dev/null 2>&1; then
    taskkill.exe /PID "$pid" /T /F >/dev/null 2>&1 || true
  elif kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
  rm -f "$file"
}
stop_pid_file "$ARTIFACTS/runtime/frontend.pid"
stop_pid_file "$ARTIFACTS/runtime/backend.pid"
echo "Service cleanup completed"
