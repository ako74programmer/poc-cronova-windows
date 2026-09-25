#!/usr/bin/env bash
set -euo pipefail

# Shared Windows/Git Bash bootstrap. Source this file from a workflow script.
CALLER_SOURCE="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
SCRIPT_DIR="$(cd "$(dirname "$CALLER_SOURCE")" && pwd)"
SCRIPTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_ROOT/../.." && pwd)"

CONFIG=""
WORKSPACE="${CRONOVA_PROJECT_DIR:-$REPO_ROOT}"
ARTIFACTS="${CRONOVA_ARTIFACTS_DIR:-$REPO_ROOT/artifacts}"

usage_common() {
  cat <<EOF
Common options:
  --config PATH       Versioned sdlc YAML configuration
  --workspace PATH    Project/workspace directory (default: CRONOVA_PROJECT_DIR or repository)
  --artifacts PATH    Artifact directory (default: artifacts)
EOF
}

normalize_path() {
  local value="$1"
  if [[ "$value" =~ ^[A-Za-z]:[\\/] || "$value" == \\\\* ]] && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$value"
  elif [[ "$value" == /* ]]; then
    printf '%s\n' "$value"
  else
    printf '%s/%s\n' "$REPO_ROOT" "$value"
  fi
}

parse_common_args() {
  while (($#)); do
    case "$1" in
      --config) CONFIG="${2:?--config requires a path}"; shift 2 ;;
      --workspace) WORKSPACE="${2:?--workspace requires a path}"; shift 2 ;;
      --artifacts) ARTIFACTS="${2:?--artifacts requires a path}"; shift 2 ;;
      --help|-h) usage_common; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage_common >&2; return 2 ;;
    esac
  done
  [[ -n "$CONFIG" ]] || { echo "Error: --config is required" >&2; return 2; }
  CONFIG="$(normalize_path "$CONFIG")"
  WORKSPACE="$(normalize_path "$WORKSPACE")"
  ARTIFACTS="$(normalize_path "$ARTIFACTS")"
  [[ -f "$CONFIG" ]] || { echo "Error: config not found: $CONFIG" >&2; return 2; }
  mkdir -p "$ARTIFACTS/logs" "$ARTIFACTS/reports" "$ARTIFACTS/metadata"
  export REPO_ROOT CONFIG WORKSPACE ARTIFACTS
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    echo "DEBUG PATH: $PATH" >&2
    echo "DEBUG which $1: $(command -v "$1" 2>&1 || true)" >&2
    return 20
  }
}

setup_toolchain() {
  local helper="$REPO_ROOT/internal/scripts/common_toolchain.sh"
  if [[ -f "$helper" ]]; then
    # shellcheck source=/dev/null
    source "$helper"
    setup_java_maven || return $?
  fi
}

log_runtime() {
  {
    printf 'repo_root=%s\nworkspace=%s\nartifacts=%s\nconfig=%s\n' "$REPO_ROOT" "$WORKSPACE" "$ARTIFACTS" "$CONFIG"
    command -v bash || true
    command -v node || true
    command -v npm || true
    command -v python || true
  } > "$ARTIFACTS/metadata/runtime.txt"
  if command -v log_toolchain_runtime >/dev/null 2>&1; then
    log_toolchain_runtime "$ARTIFACTS/metadata/toolchain-runtime.txt"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  usage_common
fi
