#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common/bootstrap.sh
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
log_runtime
require_command node
require_command npm

if grep -Eiq '(/c/Users/|/home/|/tmp/|/var/|systemd|launchd)' "$CONFIG"; then
  echo "Error: configuration contains a non-portable Unix/private path" >&2
  exit 10
fi

grep -q '^project:' "$CONFIG" || { echo "Error: Angular config lacks project section" >&2; exit 10; }
grep -q 'kind: angular' "$CONFIG" || { echo "Error: config kind must be angular" >&2; exit 10; }
node --version | tee "$ARTIFACTS/metadata/node-version.txt"
npm --version | tee "$ARTIFACTS/metadata/npm-version.txt"
echo "Angular configuration is valid: $CONFIG"
