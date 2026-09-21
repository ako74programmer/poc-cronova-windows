#!/usr/bin/env bash
set -euo pipefail

# Reads simple two-level scalar values from the project manifests used by the
# SDLC scripts. It intentionally does not pretend to be a general YAML parser.
# Complex YAML validation remains the responsibility of cronova/config tooling.
config_value() {
  local file="$1" section="$2" key="$3"
  awk -v section="$section" -v key="$key" '
    $0 ~ "^" section ":$" { inside=1; next }
    inside && $0 ~ /^[^[:space:]]/ { inside=0 }
    inside && $0 ~ "^  " key ":" {
      sub("^  " key ":[[:space:]]*", "")
      gsub(/^"|"$/, "")
      print
      exit
    }
  ' "$file"
}
