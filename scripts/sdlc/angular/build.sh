#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npm
BUILD_CONFIGURATION="$(config_value "$CONFIG" angular build_configuration || true)"
BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-production}"
cd "$WORKSPACE"
npm run build -- --configuration "$BUILD_CONFIGURATION" 2>&1 | tee "$ARTIFACTS/logs/angular-build.log"

CONFIGURED_DIST="$(config_value "$CONFIG" angular output_path || true)"
DIST_DIR="${CONFIGURED_DIST:+$WORKSPACE/$CONFIGURED_DIST}"
if [[ -n "$DIST_DIR" && ! -d "$DIST_DIR" ]]; then
  DIST_DIR=""
fi
if [[ -z "$DIST_DIR" && -d "$WORKSPACE/dist/item-portal/browser" ]]; then
  DIST_DIR="$WORKSPACE/dist/item-portal/browser"
elif [[ -d "$WORKSPACE/dist" ]]; then
  # Angular CLI 20 emits dist/<project>/index.html by default, while older
  # configurations may emit dist/<project>/browser/index.html.
  DIST_DIR="$(find "$WORKSPACE/dist" -type f -name index.html -print -quit | xargs -r dirname)"
fi
[[ -n "$DIST_DIR" && -f "$DIST_DIR/index.html" ]] || {
  echo "Error: Angular build did not produce index.html" >&2
  exit 60
}
mkdir -p "$ARTIFACTS/dist"
rm -rf "$ARTIFACTS/dist/browser"
cp -R "$DIST_DIR" "$ARTIFACTS/dist/browser"
sha256sum "$DIST_DIR/index.html" > "$ARTIFACTS/metadata/frontend-index.sha256" 2>/dev/null || shasum -a 256 "$DIST_DIR/index.html" > "$ARTIFACTS/metadata/frontend-index.sha256"
MANIFEST_NAME="$(config_value "$CONFIG" artifacts manifest || true)"
MANIFEST_NAME="${MANIFEST_NAME:-frontend-manifest.json}"
OPENAPI_FILE="$(config_value "$CONFIG" api openapi_file || true)"
MANIFEST_PATH="$ARTIFACTS/$MANIFEST_NAME"
mkdir -p "$(dirname "$MANIFEST_PATH")"
cat > "$MANIFEST_PATH" <<EOF
{
  "component": "angular",
  "project": "${WORKSPACE}",
  "artifact_directory": "${ARTIFACTS}/dist/browser",
  "openapi": "${OPENAPI_FILE:-}",
  "result": "success"
}
EOF
