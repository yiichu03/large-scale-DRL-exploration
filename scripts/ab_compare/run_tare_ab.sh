#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUTONOMY_STACK_DIR="/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform"
RUN_DIR="${ROOT_DIR}/tmp/tare_ab_run"
PID_FILE="${RUN_DIR}/pids.env"

SCENE_LABEL="${SCENE_LABEL:-${SCENE:-${UNITY_WORLD:-environment}}}"
UNITY_WORLD_NAME="${UNITY_WORLD:-environment}"
RUN_TAG="$(date +%Y%m%d_%H%M%S)_tare_${SCENE_LABEL}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/ab_runs/${RUN_TAG}}"
MONITOR_PYTHON="${MONITOR_PYTHON:-/usr/bin/python3}"
START_RVIZ="${START_RVIZ:-1}"
AUTO_STOP_ON_FINISH="${AUTO_STOP_ON_FINISH:-1}"
FINISH_GRACE_SEC="${FINISH_GRACE_SEC:-20}"
RUN_TIMEOUT_SEC="${RUN_TIMEOUT_SEC:-0}"
TARE_CONFIG="${TARE_CONFIG:-original_indoor_small}"

mkdir -p "${RUN_DIR}" "${OUTPUT_DIR}"

if [[ -f "${PID_FILE}" ]]; then
  echo "Found existing TARE pid file: ${PID_FILE}"
  echo "Run ${ROOT_DIR}/scripts/ab_compare/stop_tare_ab.sh first if the previous session is still active."
  exit 1
fi

if [[ ! -f "${AUTONOMY_STACK_DIR}/install/setup.bash" ]]; then
  echo "Missing autonomy_stack install/setup.bash"
  exit 1
fi

UNITY_BIN="${AUTONOMY_STACK_DIR}/src/base_autonomy/vehicle_simulator/mesh/unity/${UNITY_WORLD_NAME}/Model.x86_64"
RVIZ_CONFIG_PATH="${AUTONOMY_STACK_DIR}/src/exploration_planner/tare_planner/rviz/tare_planner_ground.rviz"

if [[ ! -x "${UNITY_BIN}" ]]; then
  echo "Unity executable not found or not executable: ${UNITY_BIN}"
  exit 1
fi

if [[ "${START_RVIZ}" == "1" && ! -f "${RVIZ_CONFIG_PATH}" ]]; then
  echo "RViz config not found: ${RVIZ_CONFIG_PATH}"
  exit 1
fi

set +u
source /opt/ros/humble/setup.bash
source "${AUTONOMY_STACK_DIR}/install/setup.bash"
set -u

write_pid_file() {
  cat > "${PID_FILE}" <<EOF
UNITY_PID=${UNITY_PID:-}
ROS_LAUNCH_PID=${ROS_LAUNCH_PID:-}
RVIZ_PID=${RVIZ_PID:-}
EOF
}

cleanup() {
  set +e
  "${ROOT_DIR}/scripts/ab_compare/stop_tare_ab.sh" >/dev/null 2>&1 || true
}

handle_signal() {
  local signal_name="${1:-INT}"
  echo
  echo "Received ${signal_name}, stopping TARE A/B run..."
  cleanup
  exit 130
}

trap cleanup EXIT
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM

start_bg() {
  local name="$1"
  shift
  setsid "$@" >/dev/null 2>&1 &
  local pid=$!
  echo "${name} started: pid=${pid}" >&2
  printf '%s' "${pid}"
}

start_rviz() {
  local clean_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local shell_bin="${SHELL:-/bin/bash}"
  start_bg rviz \
    env -i \
    HOME="${HOME}" \
    USER="${USER:-$(id -un)}" \
    LOGNAME="${LOGNAME:-${USER:-$(id -un)}}" \
    PATH="${clean_path}" \
    DISPLAY="${DISPLAY:-:0}" \
    XAUTHORITY="${XAUTHORITY:-}" \
    XDG_RUNTIME_DIR="${runtime_dir}" \
    TERM="${TERM:-dumb}" \
    SHELL="${shell_bin}" \
    bash -lc "set +u && source /opt/ros/humble/setup.bash && source '${AUTONOMY_STACK_DIR}/install/setup.bash' && rviz2 -d '${RVIZ_CONFIG_PATH}'"
}

START_TIME_EPOCH="$(date +%s.%N)"
UNITY_PID="$(start_bg unity "${UNITY_BIN}")"
write_pid_file
sleep 3

ROS_LAUNCH_PID="$(start_bg ros_sim ros2 launch vehicle_simulator system_simulation_with_exploration_planner.launch "exploration_planner_config:=${TARE_CONFIG}")"
write_pid_file
sleep 8

if [[ "${START_RVIZ}" == "1" ]]; then
  RVIZ_PID="$(start_rviz)"
  write_pid_file
  sleep 2
fi

MONITOR_ARGS=(
  "${MONITOR_PYTHON}" "${ROOT_DIR}/scripts/ab_compare/monitor_experiment.py"
  --method TARE
  --scene "${SCENE_LABEL}"
  --output-dir "${OUTPUT_DIR}"
  --start-time-epoch "${START_TIME_EPOCH}"
  --finish-grace-sec "${FINISH_GRACE_SEC}"
  --timeout-sec "${RUN_TIMEOUT_SEC}"
  --stop-command "${ROOT_DIR}/scripts/ab_compare/stop_tare_ab.sh"
)

if [[ "${AUTO_STOP_ON_FINISH}" == "1" ]]; then
  MONITOR_ARGS+=(--auto-stop-on-finish)
fi

"${MONITOR_ARGS[@]}"

cleanup
trap - EXIT INT TERM
echo "A/B outputs: ${OUTPUT_DIR}"
