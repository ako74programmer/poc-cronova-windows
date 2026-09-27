#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command java

JAR_VALUE="${BACKEND_JAR:-$(config_value "$CONFIG" artifacts backend_jar || true)}"
MANIFEST_VALUE="$(config_value "$CONFIG" artifacts backend_manifest || true)"
HOST="${BACKEND_HOST:-$(config_value "$CONFIG" services backend_host || true)}"
PORT="${BACKEND_PORT:-$(config_value "$CONFIG" services backend_port || true)}"
PROFILE="${BACKEND_PROFILE:-$(config_value "$CONFIG" services backend_profile || true)}"
[[ -n "$JAR_VALUE" && -n "$MANIFEST_VALUE" && -n "$HOST" && -n "$PORT" ]] || { echo "Error: backend artifact/manifest/host/port are not configured" >&2; exit 10; }
JAR="$(normalize_path "$JAR_VALUE")"
MANIFEST="$(normalize_path "$MANIFEST_VALUE")"
[[ -f "$JAR" ]] || { echo "Error: backend JAR not found: $JAR" >&2; exit 60; }
[[ -f "$MANIFEST" ]] || { echo "Error: backend manifest not found: $MANIFEST" >&2; exit 60; }
mkdir -p "$ARTIFACTS/runtime"
JAVA_ARGS=(--server.address="$HOST" --server.port="$PORT")
[[ -z "$PROFILE" ]] || JAVA_ARGS+=(--spring.profiles.active="$PROFILE")
java -jar "$JAR" "${JAVA_ARGS[@]}" > "$ARTIFACTS/runtime/backend.log" 2>&1 &
echo "$!" > "$ARTIFACTS/runtime/backend.pid"
echo "Started backend PID $(cat "$ARTIFACTS/runtime/backend.pid") at $HOST:$PORT"
