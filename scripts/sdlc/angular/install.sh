#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command npm
[[ -f "$WORKSPACE/package.json" ]] || { echo "Error: package.json not found in $WORKSPACE" >&2; exit 30; }
[[ -f "$WORKSPACE/package-lock.json" ]] || { echo "Error: package-lock.json is required for npm ci" >&2; exit 30; }
cd "$WORKSPACE"
npm ci 2>&1 | tee "$ARTIFACTS/logs/angular-npm-ci.log"
