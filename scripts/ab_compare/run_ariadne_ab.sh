#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUTONOMY_STACK_DIR="/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform"
ARIADNE_ROS_DIR="/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner"

SCENE_LABEL="${SCENE_LABEL:-${SCENE:-${UNITY_WORLD:-environment}}}"
UNITY_WORLD_NAME="${UNITY_WORLD:-environment}"
RUN_TAG="$(date +%Y%m%d_%H%M%S)_ariadne_${SCENE_LABEL}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/ab_runs/${RUN_TAG}}"
MONITOR_PYTHON="${MONITOR_PYTHON:-/usr/bin/python3}"
START_RVIZ="${START_RVIZ:-1}"
CAPTURE_LOGS="${CAPTURE_LOGS:-0}"
AUTO_STOP_ON_FINISH="${AUTO_STOP_ON_FINISH:-1}"
FINISH_GRACE_SEC="${FINISH_GRACE_SEC:-20}"
RUN_TIMEOUT_SEC="${RUN_TIMEOUT_SEC:-0}"
LAUNCH_PID=""

cleanup() {
  set +e
  "${ROOT_DIR}/scripts/stop_unity_ariadne.sh" >/dev/null 2>&1 || true
  if [[ -n "${LAUNCH_PID}" ]] && kill -0 "${LAUNCH_PID}" 2>/dev/null; then
    kill "${LAUNCH_PID}" 2>/dev/null || true
    wait "${LAUNCH_PID}" 2>/dev/null || true
  fi
}

handle_signal() {
  local signal_name="${1:-INT}"
  echo
  echo "Received ${signal_name}, stopping ARiADNE A/B run..."
  cleanup
  exit 130
}

trap cleanup EXIT
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM

mkdir -p "${OUTPUT_DIR}"
START_TIME_EPOCH="$(date +%s.%N)"

(
  cd "${ROOT_DIR}"
  START_RVIZ="${START_RVIZ}" \
  CAPTURE_LOGS="${CAPTURE_LOGS}" \
  UNITY_WORLD="${UNITY_WORLD_NAME}" \
  ./scripts/launch_unity_ariadne.sh
) &
LAUNCH_PID=$!

sleep 2
if ! kill -0 "${LAUNCH_PID}" 2>/dev/null; then
  echo "ARiADNE launcher exited unexpectedly."
  exit 1
fi

set +u
source /opt/ros/humble/setup.bash
source "${AUTONOMY_STACK_DIR}/install/setup.bash"
source "${ARIADNE_ROS_DIR}/install/setup.bash"
set -u

MONITOR_ARGS=(
  "${MONITOR_PYTHON}" "${ROOT_DIR}/scripts/ab_compare/monitor_experiment.py"
  --method ARIADNE
  --scene "${SCENE_LABEL}"
  --output-dir "${OUTPUT_DIR}"
  --start-time-epoch "${START_TIME_EPOCH}"
  --finish-grace-sec "${FINISH_GRACE_SEC}"
  --timeout-sec "${RUN_TIMEOUT_SEC}"
  --stop-command "${ROOT_DIR}/scripts/stop_unity_ariadne.sh"
)

if [[ "${AUTO_STOP_ON_FINISH}" == "1" ]]; then
  MONITOR_ARGS+=(--auto-stop-on-finish)
fi

"${MONITOR_ARGS[@]}"

cleanup
trap - EXIT INT TERM
echo "A/B outputs: ${OUTPUT_DIR}"
