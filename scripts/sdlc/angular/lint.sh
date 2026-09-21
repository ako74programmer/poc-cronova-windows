#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command npm
cd "$WORKSPACE"
npm run lint 2>&1 | tee "$ARTIFACTS/logs/angular-lint.log"
