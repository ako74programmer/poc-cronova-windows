#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bootstrap.sh"
parse_common_args "$@"
require_command python
python - "$ARTIFACTS" "$CONFIG" <<'PY'
import json, os, sys
artifacts, config = sys.argv[1:]
manifest = {
    "config": os.path.abspath(config),
    "artifacts": os.path.abspath(artifacts),
    "files": [],
}
for root, _, names in os.walk(artifacts):
    for name in names:
        path = os.path.join(root, name)
        if os.path.basename(path) != "manifest.json":
            manifest["files"].append(os.path.relpath(path, artifacts).replace(os.sep, "/"))
manifest["files"].sort()
with open(os.path.join(artifacts, "manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)
print(f"Archived {len(manifest['files'])} artifact files")
PY
