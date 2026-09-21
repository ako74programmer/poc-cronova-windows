#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command python
[[ -f "$REPO_ROOT/contracts/openapi.yaml" ]] || { echo "Error: OpenAPI contract is missing" >&2; exit 60; }
[[ -f "$REPO_ROOT/$CONFIG" || -f "$CONFIG" ]] || { echo "Error: full-stack config is missing" >&2; exit 10; }
if grep -Eiq '(/c/Users/|/home/|/tmp/|/var/|systemd|launchd)' "$CONFIG"; then
  echo "Error: full-stack config contains a non-portable path" >&2
  exit 10
fi
python - "$REPO_ROOT/contracts/openapi.yaml" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
for required in ("openapi:", "paths:", "/api/items"):
    if required not in text:
        raise SystemExit(f"missing required OpenAPI marker: {required}")
print(f"OpenAPI smoke validation passed: {path}")
PY
