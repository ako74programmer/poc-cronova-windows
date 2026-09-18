#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/generate-maven-archetype" \
  -a maven-archetype-quickstart \
  -g com.example \
  -r luhn \
  -k com.example.luhn \
  -j 21 \
  -w "$REPO_ROOT/workspaces/sdlc_maven_luhn" \
  -p app \
  -C
