#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command curl
require_command unzip
if [[ -f "$WORKSPACE/pom.xml" ]]; then
  echo "Spring Boot project already exists: $WORKSPACE"
  exit 0
fi
BOOT="$(config_value "$CONFIG" runtime spring_boot_version || true)"
JAVA="$(config_value "$CONFIG" runtime java_version || true)"
GROUP="$(config_value "$CONFIG" springboot group_id || true)"
ARTIFACT="$(config_value "$CONFIG" springboot artifact_id || true)"
PACKAGE="$(config_value "$CONFIG" springboot package_name || true)"
BOOT="${BOOT:-3.5.5}"
JAVA="${JAVA:-21}"
GROUP="${GROUP:-com.example}"
ARTIFACT="${ARTIFACT:-item-service}"
PACKAGE="${PACKAGE:-com.example.item}"
mkdir -p "$WORKSPACE" "$ARTIFACTS/metadata"
ZIP="$ARTIFACTS/metadata/springboot-starter.zip"
URL="https://start.spring.io/starter.zip?type=maven-project&language=java&bootVersion=$BOOT&javaVersion=$JAVA&groupId=$GROUP&artifactId=$ARTIFACT&name=$ARTIFACT&packageName=$PACKAGE&packaging=jar&configFormat=yaml&dependencies=web,validation,actuator"
curl -fsSL -o "$ZIP" "$URL"
unzip -q "$ZIP" -d "$WORKSPACE"
[[ -f "$WORKSPACE/pom.xml" ]] || { echo "Error: Initializr response did not contain pom.xml" >&2; exit 60; }
