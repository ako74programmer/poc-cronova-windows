#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
setup_toolchain
require_command java
require_command mvn
[[ -f "$WORKSPACE/mvnw.cmd" ]] || { echo "Error: mvnw.cmd not found in $WORKSPACE" >&2; exit 30; }
ARTIFACT_NAME="$(config_value "$CONFIG" project artifact_name || true)"
ARTIFACT_NAME="${ARTIFACT_NAME:-item-service.jar}"
MANIFEST_NAME="$(config_value "$CONFIG" artifacts manifest || true)"
MANIFEST_NAME="${MANIFEST_NAME:-backend-manifest.json}"
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
OUTPUT_JAR="$ARTIFACTS/package/$ARTIFACT_NAME"
mkdir -p "$(dirname "$OUTPUT_JAR")" "$(dirname "$ARTIFACTS/$MANIFEST_NAME")"
cp "$JAR" "$OUTPUT_JAR"
sha256sum "$JAR" > "$OUTPUT_JAR.sha256" 2>/dev/null || shasum -a 256 "$JAR" > "$OUTPUT_JAR.sha256"
cat > "$ARTIFACTS/$MANIFEST_NAME" <<EOF
{
  "component": "springboot",
  "artifact": "${OUTPUT_JAR}",
  "source_directory": "${WORKSPACE}",
  "result": "success"
}
EOF
