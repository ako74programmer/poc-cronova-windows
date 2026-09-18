#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

exec "$REPO_ROOT/internal/scripts/fetch-springboot-project" \
  -t maven-project \
  -l java \
  -b 4.0.8 \
  -g com.example \
  -a demo \
  -n com.example.demo \
  -p jar \
  -c properties \
  -j 21 \
  -d web \
  -w "$REPO_ROOT/workspaces/springboot-startio" \
  -P app \
  -C
