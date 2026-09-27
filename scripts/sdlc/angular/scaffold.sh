#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npx
require_command node
APP_NAME="$(config_value "$CONFIG" angular app_name || true)"
CLI_VERSION="$(config_value "$CONFIG" runtime angular_cli_version || true)"
APP_NAME="${APP_NAME:-item-portal}"
CLI_VERSION="${CLI_VERSION:-latest}"
setup_lint() {
	if node -e 'const p=require(process.argv[1]); process.exit(p.scripts && p.scripts.lint ? 0 : 1)' "$WORKSPACE/package.json" 2>/dev/null; then
		return 0
	fi
	echo "Adding angular-eslint to Angular workspace: $WORKSPACE"
	(
		cd "$WORKSPACE"
		npx --yes "@angular/cli@$CLI_VERSION" add "@angular-eslint/schematics@$CLI_VERSION" --skip-confirmation
	)
}
setup_test_browser() {
	if node -e 'const p=require(process.argv[1]); const d={...(p.devDependencies||{}), ...(p.dependencies||{})}; process.exit(d.puppeteer ? 0 : 1)' "$WORKSPACE/package.json" 2>/dev/null; then
		return 0
	fi
	echo "Adding Puppeteer Chromium for Angular unit tests: $WORKSPACE"
	(cd "$WORKSPACE" && npm install --save-dev --package-lock-only puppeteer@24)
}
if [[ -f "$WORKSPACE/package.json" ]]; then
	echo "Angular project already exists: $WORKSPACE"
	setup_lint
	setup_test_browser
	if [[ ! -f "$WORKSPACE/package-lock.json" ]]; then
		echo "Generating missing package-lock.json: $WORKSPACE"
		(cd "$WORKSPACE" && npm install --package-lock-only --ignore-scripts)
	fi
	exit 0
fi
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

setup_lint
setup_test_browser

# --skip-install also skips package-lock generation in Angular CLI. The next
# reusable DAG block deliberately runs `npm ci`, so create the lockfile here
# without installing dependencies; install.sh remains the single install step.
(cd "$WORKSPACE" && npm install --package-lock-only --ignore-scripts)
