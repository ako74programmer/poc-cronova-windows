#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npx
if [[ -f "$WORKSPACE/package.json" ]]; then
	  echo "Angular project already exists: $WORKSPACE"
	  if [[ ! -f "$WORKSPACE/package-lock.json" ]]; then
	    echo "Generating missing package-lock.json: $WORKSPACE"
	    (cd "$WORKSPACE" && npm install --package-lock-only --ignore-scripts)
	  fi
	  exit 0
fi
APP_NAME="$(config_value "$CONFIG" angular app_name || true)"
CLI_VERSION="$(config_value "$CONFIG" runtime angular_cli_version || true)"
APP_NAME="${APP_NAME:-item-portal}"
CLI_VERSION="${CLI_VERSION:-latest}"
mkdir -p "$WORKSPACE"
CLI_DIRECTORY="$WORKSPACE"
if [[ "$WORKSPACE" == "$REPO_ROOT/"* ]]; then
  # Angular CLI is a Windows Node process when this script runs under Git Bash.
  # Pass a repo-relative path so MSYS/Node cannot treat a converted absolute
  # path such as C:\repo\.workspaces\angular as a second relative segment.
  CLI_DIRECTORY="${WORKSPACE#"$REPO_ROOT/"}"
fi
npx --yes "@angular/cli@$CLI_VERSION" new "$APP_NAME" \
  --directory "$CLI_DIRECTORY" \
  --routing \
  --style=scss \
  --standalone \
  --skip-git \
  --package-manager=npm \
  --skip-install

# --skip-install also skips package-lock generation in Angular CLI. The next
# reusable DAG block deliberately runs `npm ci`, so create the lockfile here
# without installing dependencies; install.sh remains the single install step.
(cd "$WORKSPACE" && npm install --package-lock-only --ignore-scripts)
