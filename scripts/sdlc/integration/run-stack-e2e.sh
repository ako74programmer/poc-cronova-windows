#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/bootstrap.sh"
parse_common_args "$@"

run_step() {
  local script="$1"
  bash "$script" --config "$CONFIG" --workspace "$WORKSPACE" --artifacts "$ARTIFACTS"
}

cleanup() {
  local run_status=$?
  trap - EXIT
  set +e
  echo "Stopping stack services before Cronova task exits"
  run_step "$SCRIPT_DIR/stop-services.sh"
  local cleanup_status=$?
  if (( run_status == 0 && cleanup_status != 0 )); then
    run_status="$cleanup_status"
  fi
  exit "$run_status"
}

# Windows Cronova tasks run in a Job Object that terminates child processes when
# the task exits. Keep service processes inside this task until E2E completes.
trap cleanup EXIT

echo "Starting backend within the integration task"
run_step "$SCRIPT_DIR/start-backend.sh"
echo "Starting frontend within the integration task"
run_step "$SCRIPT_DIR/start-frontend.sh"
echo "Waiting for configured stack health endpoints"
run_step "$SCRIPT_DIR/wait-services.sh"
echo "Running configured Playwright E2E suite"
run_step "$SCRIPT_DIR/../playwright/run.sh"
