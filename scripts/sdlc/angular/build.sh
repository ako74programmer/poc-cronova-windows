#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npm
cd "$WORKSPACE"
npm run build -- --configuration production 2>&1 | tee "$ARTIFACTS/logs/angular-build.log"

CONFIGURED_DIST="$(config_value "$CONFIG" angular output_path || true)"
DIST_DIR="${CONFIGURED_DIST:+$WORKSPACE/$CONFIGURED_DIST}"
if [[ -n "$DIST_DIR" && ! -d "$DIST_DIR" ]]; then
  DIST_DIR=""
fi
if [[ -z "$DIST_DIR" && -d "$WORKSPACE/dist/item-portal/browser" ]]; then
  DIST_DIR="$WORKSPACE/dist/item-portal/browser"
elif [[ -d "$WORKSPACE/dist" ]]; then
  DIST_DIR="$WORKSPACE/dist"
fi
[[ -n "$DIST_DIR" && -f "$DIST_DIR/index.html" ]] || {
  echo "Error: Angular build did not produce index.html" >&2
  exit 60
}
mkdir -p "$ARTIFACTS/dist"
cp -R "$DIST_DIR" "$ARTIFACTS/dist/browser"
sha256sum "$DIST_DIR/index.html" > "$ARTIFACTS/metadata/frontend-index.sha256" 2>/dev/null || shasum -a 256 "$DIST_DIR/index.html" > "$ARTIFACTS/metadata/frontend-index.sha256"
cat > "$ARTIFACTS/frontend-manifest.json" <<EOF
{
  "component": "angular",
  "project": "${WORKSPACE}",
  "artifact_directory": "${ARTIFACTS}/dist/browser",
  "openapi": "contracts/openapi.yaml",
  "result": "success"
}
EOF
