#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/compile-project" \
  -w "$REPO_ROOT/workspaces/sdlc_maven_luhn" \
  -p app
