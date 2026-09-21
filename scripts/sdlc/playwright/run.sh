#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command npm
E2E_DIR="$REPO_ROOT/e2e/playwright"
[[ -d "$E2E_DIR/node_modules" ]] || { echo "Error: Playwright dependencies are not installed" >&2; exit 30; }
mkdir -p "$ARTIFACTS/playwright"
cd "$E2E_DIR"
FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:4300}" \
  PW_WORKERS="${PW_WORKERS:-1}" \
  npx playwright test 2>&1 | tee "$ARTIFACTS/logs/playwright.log"
