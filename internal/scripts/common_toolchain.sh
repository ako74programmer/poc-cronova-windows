#!/usr/bin/env bash
set -euo pipefail

# Shared Java/Maven toolchain setup for cronova SDLC scripts.
# Sources this file to ensure JAVA_HOME and Maven are on PATH before
# running builds. Handles both Windows (C:\...) and Unix (/c/...) paths
# when running under Git Bash / MSYS.

# Convert a path to Unix form when running under Git Bash/MSYS/Cygwin.
__ct_normalize_path() {
  local path="$1"
  if [[ -z "$path" ]]; then
    return 0
  fi
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$path" 2>/dev/null || printf '%s\n' "$path"
  else
    printf '%s\n' "$path"
  fi
}

# Prepend a directory to PATH if it exists and is not already present.
__ct_prepend_path() {
  local dir="$1"
  if [[ -z "$dir" || ! -d "$dir" ]]; then
    return 0
  fi
  case ":${PATH}:" in
    *:"$dir":*) ;;
    *) export PATH="$dir${PATH:+:$PATH}" ;;
  esac
}

__ct_add_executable_dir() {
  local executable="$1"
  [[ -n "$executable" ]] || return 0
  executable="$(__ct_normalize_path "$executable")"
  [[ -f "$executable" ]] || return 0
  __ct_prepend_path "$(dirname "$executable")"
}

# Resolve an explicit Python command/path or autodetect python3/python.
# Windows paths supplied through CRONOVA_PYTHON are normalized for Git Bash.
find_python() {
  local requested="${1:-}"
  local configured="${CRONOVA_PYTHON:-}"
  local found=""

  # DAGs may pass -y python as a generic selector. Prefer the concrete
  # operator-configured executable in that case (for example a Windows path).
  if [[ -z "$requested" || "$requested" == "python" || "$requested" == "python3" ]]; then
    requested="$configured"
  fi

  if [[ -n "$requested" ]]; then
    case "$requested" in
      *\\*|[A-Za-z]:*) requested="$(__ct_normalize_path "$requested")" ;;
    esac
    found="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
      printf '%s\n' "$found"
      return 0
    fi
    if [[ -x "$requested" ]]; then
      printf '%s\n' "$requested"
      return 0
    fi
    echo "Error: configured Python is not executable: $requested" >&2
    return 1
  fi

  for requested in python3 python; do
    found="$(command -v "$requested" 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
      printf '%s\n' "$found"
      return 0
    fi
  done

  echo "Error: Python not found; install Python or set CRONOVA_PYTHON to its executable path." >&2
  return 1
}

setup_windows_path() {
  local windows_path="${CRONOVA_WINDOWS_PATH:-}"
  [[ -n "$windows_path" ]] || return 0
  if command -v cygpath >/dev/null 2>&1; then
    windows_path="$(cygpath -pu "$windows_path" 2>/dev/null || true)"
  fi
  [[ -n "$windows_path" ]] || return 0
  export PATH="$windows_path${PATH:+:$PATH}"
}

setup_runtime_tools() {
  setup_windows_path
  __ct_add_executable_dir "${CRONOVA_PYTHON:-}"
  __ct_add_executable_dir "${CRONOVA_NODE:-}"
  __ct_add_executable_dir "${CRONOVA_NPM:-}"
}

setup_java_maven() {
  local java_home="${CRONOVA_JAVA_HOME:-${JAVA_HOME:-}}"
  local maven_home="${CRONOVA_MAVEN_HOME:-${MAVEN_HOME:-}}"

  setup_runtime_tools

  if [[ -n "$java_home" ]]; then
    java_home="$(__ct_normalize_path "$java_home")"
    export JAVA_HOME="$java_home"
    __ct_prepend_path "$JAVA_HOME/bin"
  fi

  if [[ -n "$maven_home" ]]; then
    maven_home="$(__ct_normalize_path "$maven_home")"
    export MAVEN_HOME="$maven_home"
    __ct_prepend_path "$MAVEN_HOME/bin"
  fi

  if ! command -v java >/dev/null 2>&1; then
    echo "Error: java not found in PATH" >&2
    echo "DEBUG PATH=$PATH" >&2
    echo "DEBUG JAVA_HOME=${JAVA_HOME:-<unset>}" >&2
    echo "DEBUG CRONOVA_JAVA_HOME=${CRONOVA_JAVA_HOME:-<unset>}" >&2
    return 20
  fi

  if ! command -v mvn >/dev/null 2>&1; then
    echo "Error: mvn not found in PATH" >&2
    echo "DEBUG PATH=$PATH" >&2
    echo "DEBUG MAVEN_HOME=${MAVEN_HOME:-<unset>}" >&2
    echo "DEBUG CRONOVA_MAVEN_HOME=${CRONOVA_MAVEN_HOME:-<unset>}" >&2
    return 20
  fi

  return 0
}

log_toolchain_runtime() {
  local out="${1:-/dev/stdout}"
  {
    printf 'PATH=%s\n' "$PATH"
    printf 'JAVA_HOME=%s\n' "${JAVA_HOME:-<unset>}"
    printf 'CRONOVA_JAVA_HOME=%s\n' "${CRONOVA_JAVA_HOME:-<unset>}"
    printf 'MAVEN_HOME=%s\n' "${MAVEN_HOME:-<unset>}"
    printf 'CRONOVA_MAVEN_HOME=%s\n' "${CRONOVA_MAVEN_HOME:-<unset>}"
    printf 'java=%s\n' "$(command -v java 2>/dev/null || true)"
    java -version 2>&1 || true
    printf 'mvn=%s\n' "$(command -v mvn 2>/dev/null || true)"
    mvn -version 2>&1 | head -n 3 || true
  } > "$out"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  setup_java_maven
  log_toolchain_runtime
fi
