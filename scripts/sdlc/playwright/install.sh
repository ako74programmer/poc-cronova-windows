#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npm
E2E_VALUE="$(config_value "$CONFIG" playwright directory || true)"
BROWSER="$(config_value "$CONFIG" playwright browser || true)"
[[ -n "$E2E_VALUE" && -n "$BROWSER" ]] || { echo "Error: Playwright directory/browser are not configured" >&2; exit 10; }
E2E_DIR="$(normalize_path "$E2E_VALUE")"
[[ -f "$E2E_DIR/package.json" ]] || { echo "Error: Playwright package.json is missing: $E2E_DIR" >&2; exit 30; }
[[ -f "$E2E_DIR/package-lock.json" ]] || { echo "Error: Playwright package-lock.json is required for a reproducible install" >&2; exit 30; }
cd "$E2E_DIR"
npm ci
npx playwright install "$BROWSER"
