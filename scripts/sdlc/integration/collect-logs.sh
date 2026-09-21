#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
for file in "$ARTIFACTS/runtime/backend.log" "$ARTIFACTS/runtime/frontend.log"; do
  [[ -f "$file" ]] && cp "$file" "$ARTIFACTS/logs/$(basename "$file")"
done
