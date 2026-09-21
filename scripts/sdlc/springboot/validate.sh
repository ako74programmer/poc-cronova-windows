#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
require_command java
if grep -Eiq '(/c/Users/|/home/|/tmp/|/var/|systemd|launchd)' "$CONFIG"; then
  echo "Error: configuration contains a non-portable Unix/private path" >&2
  exit 10
fi
grep -q '^project:' "$CONFIG" || { echo "Error: Spring Boot config lacks project section" >&2; exit 10; }
grep -q 'kind: springboot' "$CONFIG" || { echo "Error: config kind must be springboot" >&2; exit 10; }
java -version 2> "$ARTIFACTS/metadata/java-version.txt"
cat "$ARTIFACTS/metadata/java-version.txt"
echo "Spring Boot configuration is valid: $CONFIG"
