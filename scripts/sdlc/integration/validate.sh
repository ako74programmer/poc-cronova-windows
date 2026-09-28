#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
source "$SCRIPT_DIR/../common/config-value.sh"
parse_common_args "$@"
require_command python

if grep -Eiq '(/c/Users/|/home/|/tmp/|/var/|systemd|launchd)' "$CONFIG"; then
  echo "Error: full-stack config contains a non-portable path" >&2
  exit 10
fi

required_config() {
  local section="$1" key="$2" value="$3"
  [[ -n "$value" ]] || { echo "Error: missing $section.$key in $CONFIG" >&2; exit 10; }
}

ANGULAR_CONFIG="$(config_value "$CONFIG" stack angular_config || true)"
SPRINGBOOT_CONFIG="$(config_value "$CONFIG" stack springboot_config || true)"
OPENAPI_FILE="$(config_value "$CONFIG" stack openapi_file || true)"
FRONTEND_DIST="$(config_value "$CONFIG" artifacts frontend_dist || true)"
FRONTEND_MANIFEST="$(config_value "$CONFIG" artifacts frontend_manifest || true)"
BACKEND_JAR="$(config_value "$CONFIG" artifacts backend_jar || true)"
BACKEND_MANIFEST="$(config_value "$CONFIG" artifacts backend_manifest || true)"
BACKEND_HEALTH_URL="$(config_value "$CONFIG" services backend_health_url || true)"
FRONTEND_URL="$(config_value "$CONFIG" services frontend_url || true)"
PLAYWRIGHT_DIR="$(config_value "$CONFIG" playwright directory || true)"
PLAYWRIGHT_BASE_URL="$(config_value "$CONFIG" playwright base_url || true)"
PLAYWRIGHT_API_URL="$(config_value "$CONFIG" playwright api_url || true)"

required_config stack angular_config "$ANGULAR_CONFIG"
required_config stack springboot_config "$SPRINGBOOT_CONFIG"
required_config stack openapi_file "$OPENAPI_FILE"
required_config artifacts frontend_dist "$FRONTEND_DIST"
required_config artifacts frontend_manifest "$FRONTEND_MANIFEST"
required_config artifacts backend_jar "$BACKEND_JAR"
required_config artifacts backend_manifest "$BACKEND_MANIFEST"
required_config services backend_health_url "$BACKEND_HEALTH_URL"
required_config services frontend_url "$FRONTEND_URL"
required_config playwright directory "$PLAYWRIGHT_DIR"
required_config playwright base_url "$PLAYWRIGHT_BASE_URL"
required_config playwright api_url "$PLAYWRIGHT_API_URL"

for path in "$ANGULAR_CONFIG" "$SPRINGBOOT_CONFIG" "$OPENAPI_FILE"; do
  normalized="$(normalize_path "$path")"
  [[ -f "$normalized" ]] || { echo "Error: configured file not found: $normalized" >&2; exit 60; }
done

OPENAPI_PATH="$(normalize_path "$OPENAPI_FILE")"
python "$SCRIPT_DIR/generate_contract_app.py" --contract "$OPENAPI_PATH"

ANGULAR_CONFIG_PATH="$(normalize_path "$ANGULAR_CONFIG")"
ANGULAR_API_URL="$(config_value "$ANGULAR_CONFIG_PATH" api base_url || true)"
required_config angular api.base_url "$ANGULAR_API_URL"
python - "$ANGULAR_API_URL" "$PLAYWRIGHT_API_URL" "$BACKEND_HEALTH_URL" "$FRONTEND_URL" "$PLAYWRIGHT_BASE_URL" <<'PY'
import sys
from urllib.parse import urlsplit

angular_api, playwright_api, backend_health, frontend, playwright_frontend = sys.argv[1:]
if angular_api.rstrip("/") != playwright_api.rstrip("/"):
    raise SystemExit("Angular api.base_url and Fullstack playwright.api_url must match")
if frontend.rstrip("/") != playwright_frontend.rstrip("/"):
    raise SystemExit("Fullstack services.frontend_url and playwright.base_url must match")
api = urlsplit(angular_api)
health = urlsplit(backend_health)
if not api.scheme or api.scheme not in ("http", "https") or api.netloc != health.netloc:
    raise SystemExit("Angular API URL must use the same HTTP(S) host/port as the configured backend")
if api.path.rstrip("/") != "/api":
    raise SystemExit("Angular API URL path must match the Item API /api prefix")
print("Frontend, Playwright, and backend API URLs are aligned")
PY

[[ "$FRONTEND_URL" == http://* || "$FRONTEND_URL" == https://* ]] || { echo "Error: services.frontend_url must be an HTTP(S) URL" >&2; exit 10; }
[[ "$BACKEND_HEALTH_URL" == http://* || "$BACKEND_HEALTH_URL" == https://* ]] || { echo "Error: services.backend_health_url must be an HTTP(S) URL" >&2; exit 10; }
echo "Full-stack configuration is valid: $CONFIG"
