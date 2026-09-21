#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
[[ -f "$ARTIFACTS/dist/browser/index.html" ]] || { echo "Error: frontend artifact missing" >&2; exit 60; }
grep -qi '<html' "$ARTIFACTS/dist/browser/index.html" || { echo "Error: index.html is not valid HTML" >&2; exit 60; }
echo "Angular artifact smoke test passed"
