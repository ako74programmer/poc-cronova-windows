#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
copied=0
for file in "$ARTIFACTS/runtime/backend.log" "$ARTIFACTS/runtime/frontend.log"; do
  if [[ -f "$file" ]]; then
    cp "$file" "$ARTIFACTS/logs/$(basename "$file")"
    copied=$((copied + 1))
  fi
done
echo "Collected $copied service log(s)"
