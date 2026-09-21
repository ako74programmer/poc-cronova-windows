#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command java
JAR="${BACKEND_JAR:-$REPO_ROOT/artifacts/springboot/package/item-service.jar}"
PORT="${BACKEND_PORT:-18080}"
[[ -f "$JAR" ]] || { echo "Error: backend JAR not found: $JAR" >&2; exit 60; }
mkdir -p "$ARTIFACTS/runtime"
java -jar "$JAR" --server.port="$PORT" --spring.profiles.active=e2e > "$ARTIFACTS/runtime/backend.log" 2>&1 &
echo "$!" > "$ARTIFACTS/runtime/backend.pid"
echo "Started backend PID $(cat "$ARTIFACTS/runtime/backend.pid") on port $PORT"
