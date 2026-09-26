#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"
setup_toolchain
require_command java
require_command mvn
[[ -f "$WORKSPACE/mvnw.cmd" ]] || { echo "Error: mvnw.cmd not found in $WORKSPACE" >&2; exit 30; }
cd "$WORKSPACE"
./mvnw.cmd -B package -DskipTests 2>&1 | tee "$ARTIFACTS/logs/springboot-package.log"
JAR=""
for candidate in target/*.jar; do
  [[ -f "$candidate" ]] || continue
  [[ "$candidate" == *-plain.jar ]] && continue
  JAR="$candidate"
  break
done
[[ -n "$JAR" ]] || { echo "Error: executable Spring Boot JAR not found" >&2; exit 60; }
mkdir -p "$ARTIFACTS/package"
cp "$JAR" "$ARTIFACTS/package/item-service.jar"
sha256sum "$JAR" > "$ARTIFACTS/package/item-service.jar.sha256" 2>/dev/null || shasum -a 256 "$JAR" > "$ARTIFACTS/package/item-service.jar.sha256"
cat > "$ARTIFACTS/backend-manifest.json" <<EOF
{
  "component": "springboot",
  "artifact": "${ARTIFACTS}/package/item-service.jar",
  "source_directory": "${WORKSPACE}",
  "result": "success"
}
EOF
