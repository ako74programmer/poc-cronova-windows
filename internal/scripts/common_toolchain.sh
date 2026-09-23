#!/usr/bin/env bash
# Shared, portable toolchain discovery for reusable internal/scripts blocks.
set -euo pipefail

find_python() {
  if [[ -n "${CRONOVA_PYTHON:-}" ]] && command -v "$CRONOVA_PYTHON" >/dev/null 2>&1; then
    command -v "$CRONOVA_PYTHON"
    return 0
  fi
  for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
      command -v "$candidate"
      return 0
    fi
  done
  if command -v py.exe >/dev/null 2>&1; then
    command -v py.exe
    return 0
  fi
  echo "Error: Python was not found. Install Python or set CRONOVA_PYTHON." >&2
  return 20
}

setup_java_maven() {
  if [[ -n "${CRONOVA_JAVA_HOME:-}" ]]; then
    export JAVA_HOME="$CRONOVA_JAVA_HOME"
  fi
  if [[ -n "${MAVEN_HOME:-}" && -d "$MAVEN_HOME/bin" ]]; then
    export PATH="$MAVEN_HOME/bin:$PATH"
  elif [[ -n "${CRONOVA_MAVEN_HOME:-}" && -d "$CRONOVA_MAVEN_HOME/bin" ]]; then
    export PATH="$CRONOVA_MAVEN_HOME/bin:$PATH"
  fi
  command -v java >/dev/null 2>&1 || {
    echo "Error: Java was not found. Install a JDK or set JAVA_HOME/CRONOVA_JAVA_HOME." >&2
    return 20
  }
  command -v mvn >/dev/null 2>&1 || {
    echo "Error: Maven was not found. Install Maven or set MAVEN_HOME/CRONOVA_MAVEN_HOME." >&2
    return 20
  }
}
