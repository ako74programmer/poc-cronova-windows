#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/ai-generate-crud" \
  -w "$REPO_ROOT/workspaces/springboot-startio" \
  -p app \
  -k com.example.demo \
  -r default
