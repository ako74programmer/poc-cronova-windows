#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
[[ -f "$WORKSPACE/mvnw.cmd" ]] || { echo "Error: mvnw.cmd not found in $WORKSPACE" >&2; exit 30; }
cd "$WORKSPACE"
./mvnw.cmd -B test 2>&1 | tee "$ARTIFACTS/logs/springboot-unit-tests.log"
