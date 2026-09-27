#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command npm
cd "$WORKSPACE"
# The project's package.json owns the concrete test runner (Vitest/Karma/etc.).
if [[ -z "${CHROME_BIN:-}" ]] && node -e 'require("puppeteer")' >/dev/null 2>&1; then
	CHROME_BIN="$(node -e 'process.stdout.write(require("puppeteer").executablePath())')"
	export CHROME_BIN
	echo "Using Puppeteer Chrome: $CHROME_BIN"
fi
npm test -- --watch=false 2>&1 | tee "$ARTIFACTS/logs/angular-unit-tests.log"
