#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/ai-generate-feature" \
  -f "$REPO_ROOT/prompts/luhn.txt" \
  -w "$REPO_ROOT/workspaces/sdlc_maven_luhn" \
  -p app \
  -k com.example.luhn
