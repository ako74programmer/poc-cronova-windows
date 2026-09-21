#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npx
if [[ -f "$WORKSPACE/package.json" ]]; then
  echo "Angular project already exists: $WORKSPACE"
  exit 0
fi
APP_NAME="$(config_value "$CONFIG" angular app_name || true)"
CLI_VERSION="$(config_value "$CONFIG" runtime angular_cli_version || true)"
APP_NAME="${APP_NAME:-item-portal}"
CLI_VERSION="${CLI_VERSION:-latest}"
mkdir -p "$WORKSPACE"
npx --yes "@angular/cli@$CLI_VERSION" new "$APP_NAME" \
  --directory "$WORKSPACE" \
  --routing \
  --style=scss \
  --standalone \
  --skip-git \
  --package-manager=npm \
  --skip-install
