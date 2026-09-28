#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command python

ANGULAR_CONFIG_VALUE="$(config_value "$CONFIG" stack angular_config || true)"
SPRINGBOOT_CONFIG_VALUE="$(config_value "$CONFIG" stack springboot_config || true)"
OPENAPI_VALUE="$(config_value "$CONFIG" stack openapi_file || true)"
[[ -n "$ANGULAR_CONFIG_VALUE" && -n "$SPRINGBOOT_CONFIG_VALUE" && -n "$OPENAPI_VALUE" ]] || {
  echo "Error: Fullstack config must define both component configs and an OpenAPI contract" >&2
  exit 10
}
ANGULAR_CONFIG="$(normalize_path "$ANGULAR_CONFIG_VALUE")"
SPRINGBOOT_CONFIG="$(normalize_path "$SPRINGBOOT_CONFIG_VALUE")"
OPENAPI_FILE="$(normalize_path "$OPENAPI_VALUE")"
[[ -f "$ANGULAR_CONFIG" && -f "$SPRINGBOOT_CONFIG" && -f "$OPENAPI_FILE" ]] || {
  echo "Error: component config or OpenAPI contract not found" >&2
  exit 60
}

ANGULAR_WORKSPACE_VALUE="$(config_value "$ANGULAR_CONFIG" workspace directory || true)"
SPRINGBOOT_WORKSPACE_VALUE="$(config_value "$SPRINGBOOT_CONFIG" workspace directory || true)"
BACKEND_PACKAGE="$(config_value "$SPRINGBOOT_CONFIG" springboot package_name || true)"
API_BASE_URL="$(config_value "$ANGULAR_CONFIG" api base_url || true)"
FRONTEND_ORIGIN="$(config_value "$CONFIG" services frontend_url || true)"
[[ -n "$ANGULAR_WORKSPACE_VALUE" && -n "$SPRINGBOOT_WORKSPACE_VALUE" && -n "$BACKEND_PACKAGE" && -n "$API_BASE_URL" && -n "$FRONTEND_ORIGIN" ]] || {
  echo "Error: component workspace/package/API URL or frontend URL is not configured" >&2
  exit 10
}

ANGULAR_WORKSPACE="$(normalize_path "$ANGULAR_WORKSPACE_VALUE")"
SPRINGBOOT_WORKSPACE="$(normalize_path "$SPRINGBOOT_WORKSPACE_VALUE")"
python "$SCRIPT_DIR/generate_contract_app.py" \
  --contract "$OPENAPI_FILE" \
  --backend-workspace "$SPRINGBOOT_WORKSPACE" \
  --frontend-workspace "$ANGULAR_WORKSPACE" \
  --backend-package "$BACKEND_PACKAGE" \
  --api-base-url "$API_BASE_URL" \
  --frontend-origin "$FRONTEND_ORIGIN"
