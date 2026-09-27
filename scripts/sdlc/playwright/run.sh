#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command npm

E2E_VALUE="$(config_value "$CONFIG" playwright directory || true)"
FRONTEND_URL="$(config_value "$CONFIG" playwright base_url || true)"
API_URL="$(config_value "$CONFIG" playwright api_url || true)"
PW_BROWSER="$(config_value "$CONFIG" playwright browser || true)"
PW_WORKERS="$(config_value "$CONFIG" playwright workers || true)"
PW_RETRIES="$(config_value "$CONFIG" playwright retries || true)"
PW_TRACE="$(config_value "$CONFIG" playwright trace || true)"
PW_SCREENSHOT="$(config_value "$CONFIG" playwright screenshot || true)"
PW_VIDEO="$(config_value "$CONFIG" playwright video || true)"
[[ -n "$E2E_VALUE" && -n "$FRONTEND_URL" && -n "$PW_BROWSER" ]] || { echo "Error: Playwright directory/base_url/browser are not configured" >&2; exit 10; }
E2E_DIR="$(normalize_path "$E2E_VALUE")"
[[ -d "$E2E_DIR/node_modules" ]] || { echo "Error: Playwright dependencies are not installed in $E2E_DIR" >&2; exit 30; }
mkdir -p "$ARTIFACTS/playwright"
REPORT_DIR="$ARTIFACTS/playwright"
if command -v cygpath >/dev/null 2>&1; then
  REPORT_DIR="$(cygpath -w "$REPORT_DIR")"
fi
cd "$E2E_DIR"
FRONTEND_URL="$FRONTEND_URL" \
API_URL="$API_URL" \
PW_BROWSER="$PW_BROWSER" \
PW_WORKERS="${PW_WORKERS:-1}" \
PW_RETRIES="${PW_RETRIES:-0}" \
PW_TRACE="${PW_TRACE:-retain-on-failure}" \
PW_SCREENSHOT="${PW_SCREENSHOT:-only-on-failure}" \
PW_VIDEO="${PW_VIDEO:-retain-on-failure}" \
PW_REPORT_DIR="$REPORT_DIR" \
  npx playwright test 2>&1 | tee "$ARTIFACTS/logs/playwright.log"
