#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command npm
E2E_DIR="$REPO_ROOT/e2e/playwright"
[[ -f "$E2E_DIR/package.json" ]] || { echo "Error: Playwright package.json is missing" >&2; exit 30; }
cd "$E2E_DIR"
if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
npx playwright install chromium
