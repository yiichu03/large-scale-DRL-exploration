#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THERMAL_NAV_DIR="$(dirname "${ROOT_DIR}")"
OFFICIAL_ENV_DIR="${OFFICIAL_ENV_DIR:-${THERMAL_NAV_DIR}/autonomous_exploration_development_environment}"
CURRENT_STACK_DIR="${CURRENT_STACK_DIR:-${THERMAL_NAV_DIR}/autonomy_stack_mecanum_wheel_platform}"
SYSTEM_LAUNCH_FILE="${SYSTEM_LAUNCH_FILE:-${ROOT_DIR}/scripts/gazebo/launch/official_system_perception_no_xacro.launch.py}"
RVIZ_CONFIG_FILE="${RVIZ_CONFIG_FILE:-${ROOT_DIR}/scripts/gazebo/rviz/official_gazebo_tare_garage.rviz}"
TARE_PARAM_FILE="${TARE_PARAM_FILE:-${ROOT_DIR}/scripts/gazebo/config/tare_garage_current_stack.yaml}"
RUN_DIR="${RUN_DIR:-${ROOT_DIR}/tmp/official_gazebo_tare_current_stack_run}"
PID_FILE="${RUN_DIR}/pids.env"

START_SYSTEM="${START_SYSTEM:-1}"
START_RVIZ="${START_RVIZ:-0}"
START_JOY="${START_JOY:-0}"
START_MONITOR="${START_MONITOR:-1}"
START_OCTOMAP="${START_OCTOMAP:-1}"
SCENE="${SCENE:-garage}"
GAZEBO_GUI="${GAZEBO_GUI:-false}"
CHECK_TERRAIN_CONN="${CHECK_TERRAIN_CONN:-true}"

LOCAL_PLANNER_CONFIG="${LOCAL_PLANNER_CONFIG:-standard}"
MAX_SPEED="${MAX_SPEED:-0.5}"
AUTONOMY_SPEED="${AUTONOMY_SPEED:-${MAX_SPEED}}"
TWO_WAY_DRIVE="${TWO_WAY_DRIVE:-true}"
CAMERA_OFFSET_Z="${CAMERA_OFFSET_Z:-0.0}"
VEHICLE_LENGTH="${VEHICLE_LENGTH:-0.70}"
VEHICLE_WIDTH="${VEHICLE_WIDTH:-0.60}"
ENABLE_DEBUG_LOG="${ENABLE_DEBUG_LOG:-0}"
DEBUG_LOG_DIR="${DEBUG_LOG_DIR:-${ROOT_DIR}/runtime_logs/official_gazebo_tare_current_stack}"
DEBUG_LOG_DECIMATION="${DEBUG_LOG_DECIMATION:-10}"
_RUN_TAG="$(date +%Y%m%d_%H%M%S)_${SCENE}"
MONITOR_OUTPUT_DIR="${MONITOR_OUTPUT_DIR:-${RUN_DIR}/trajectory_monitor_${_RUN_TAG}}"
MONITOR_SAMPLE_PERIOD_SEC="${MONITOR_SAMPLE_PERIOD_SEC:-0.2}"
MONITOR_SAMPLE_DISTANCE_M="${MONITOR_SAMPLE_DISTANCE_M:-0.05}"

if [[ "${SCENE}" != "garage" && "${TARE_PARAM_FILE}" == "${ROOT_DIR}/scripts/gazebo/config/tare_garage_current_stack.yaml" ]]; then
  echo "SCENE=${SCENE} is using the garage TARE parameter file by default." >&2
  echo "Set TARE_PARAM_FILE explicitly if you want to run a non-garage scene." >&2
  exit 1
fi

if [[ ! -f /opt/ros/humble/setup.bash ]]; then
  echo "Missing ROS2 Humble setup: /opt/ros/humble/setup.bash" >&2
  exit 1
fi

if [[ ! -f "${OFFICIAL_ENV_DIR}/install/setup.bash" ]]; then
  echo "Missing official environment install/setup.bash: ${OFFICIAL_ENV_DIR}/install/setup.bash" >&2
  exit 1
fi

if [[ ! -f "${CURRENT_STACK_DIR}/install/setup.bash" ]]; then
  echo "Missing current stack install/setup.bash: ${CURRENT_STACK_DIR}/install/setup.bash" >&2
  exit 1
fi

if [[ ! -f "${SYSTEM_LAUNCH_FILE}" ]]; then
  echo "Missing system launch file: ${SYSTEM_LAUNCH_FILE}" >&2
  exit 1
fi

if [[ ! -f "${TARE_PARAM_FILE}" ]]; then
  echo "Missing TARE param file: ${TARE_PARAM_FILE}" >&2
  exit 1
fi

if [[ ! -f "${RVIZ_CONFIG_FILE}" ]]; then
  echo "Missing RViz config: ${RVIZ_CONFIG_FILE}" >&2
  exit 1
fi

mkdir -p "${RUN_DIR}"

if [[ -f "${PID_FILE}" ]]; then
  echo "Found existing pid file: ${PID_FILE}" >&2
  echo "Run ${ROOT_DIR}/scripts/gazebo/stop_official_tare_current_stack.sh first." >&2
  exit 1
fi

DEBUG_LOG_BOOL="false"
if [[ "${ENABLE_DEBUG_LOG}" == "1" ]]; then
  DEBUG_LOG_BOOL="true"
  mkdir -p "${DEBUG_LOG_DIR}"
fi

cleanup() {
  set +e
  for pid in "${MONITOR_PID:-}" "${OCTOMAP_PID:-}" "${TARE_PID:-}" "${LOCAL_PLANNER_PID:-}" "${SYSTEM_PID:-}" "${RVIZ_PID:-}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
    fi
  done
  # give monitor a moment to finalize outputs
  if [[ -n "${MONITOR_PID:-}" ]]; then
    for _ in 1 2 3 4 5; do
      kill -0 "${MONITOR_PID}" 2>/dev/null || break
      sleep 0.5
    done
  fi
  rm -f "${PID_FILE}"
}

handle_signal() {
  local exit_code="$1"
  trap - EXIT INT TERM
  cleanup
  exit "${exit_code}"
}

trap cleanup EXIT
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
export GAZEBO_HOME="${GAZEBO_HOME:-${ROOT_DIR}/tmp/gazebo_home}"
export ROS_LOG_DIR="${ROS_LOG_DIR:-${ROOT_DIR}/tmp/roslogs_official_tare_current_stack}"
mkdir -p "${GAZEBO_HOME}" "${ROS_LOG_DIR}"

set +u
source /opt/ros/humble/setup.bash
source "${OFFICIAL_ENV_DIR}/install/setup.bash"
set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:${PATH}"

start_bg() {
  setsid "$@" >/dev/null 2>&1 &
  printf '%s' "$!"
}

has_stale_processes() {
  local patterns=(
    "${ROOT_DIR}/scripts/gazebo/monitor_xyz_trajectory.py"
    "${ROOT_DIR}/scripts/gazebo/launch/official_system_perception_no_xacro.launch.py"
    "${CURRENT_STACK_DIR}/install/local_planner/lib/local_planner/localPlanner"
    "${CURRENT_STACK_DIR}/install/local_planner/lib/local_planner/pathFollower"
    "${CURRENT_STACK_DIR}/install/tare_planner/lib/tare_planner/tare_planner_node"
    "${OFFICIAL_ENV_DIR}/install/vehicle_simulator/lib/vehicle_simulator/vehicleSimulator"
    "${OFFICIAL_ENV_DIR}/install/sensor_scan_generation/lib/sensor_scan_generation/sensorScanGeneration"
    "${OFFICIAL_ENV_DIR}/install/terrain_analysis/lib/terrain_analysis/terrainAnalysis"
    "${OFFICIAL_ENV_DIR}/install/terrain_analysis_ext/lib/terrain_analysis_ext/terrainAnalysisExt"
    'gzserver .*vehicle_simulator/world/.*\.world'
    'gzclient --gui-client-plugin=libgazebo_ros_eol_gui.so'
    '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /vehicle'
    '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /camera'
  )
  local pattern
  for pattern in "${patterns[@]}"; do
    if pgrep -f "${pattern}" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

write_pid_file() {
  cat > "${PID_FILE}" <<EOF
SYSTEM_PID=${SYSTEM_PID:-}
OCTOMAP_PID=${OCTOMAP_PID:-}
LOCAL_PLANNER_PID=${LOCAL_PLANNER_PID:-}
TARE_PID=${TARE_PID:-}
MONITOR_PID=${MONITOR_PID:-}
RVIZ_PID=${RVIZ_PID:-}
EOF
}

wait_for_topic() {
  local topic="$1"
  local timeout_sec="${2:-60}"
  local start_sec
  start_sec="$(date +%s)"
  while true; do
    if ros2 topic list 2>/dev/null | grep -qx "${topic}"; then
      echo "Topic ready: ${topic}"
      return 0
    fi
    if (( "$(date +%s)" - start_sec >= timeout_sec )); then
      echo "Timeout waiting for topic: ${topic}" >&2
      return 1
    fi
    sleep 1
  done
}

activate_current_stack_env() {
  set +u
  source "${CURRENT_STACK_DIR}/install/setup.bash"
  set -u
  export LD_LIBRARY_PATH="${CURRENT_STACK_DIR}/install/tare_planner/lib:${LD_LIBRARY_PATH:-}"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:${PATH}"
}

assert_pkg_prefix() {
  local package_name="$1"
  local prefix
  prefix="$(ros2 pkg prefix "${package_name}" 2>/dev/null || true)"
  if [[ -z "${prefix}" ]]; then
    echo "Unable to resolve ROS2 package prefix for ${package_name}" >&2
    exit 1
  fi
  if [[ "${prefix}" != "${CURRENT_STACK_DIR}/install/"* ]]; then
    echo "Package ${package_name} resolved to ${prefix}, expected current stack under ${CURRENT_STACK_DIR}/install" >&2
    exit 1
  fi
}

start_rviz_bg() {
  local display_value="${DISPLAY:-}"
  local xauthority_value="${XAUTHORITY:-}"
  local xdg_runtime_dir_value="${XDG_RUNTIME_DIR:-}"
  local term_value="${TERM:-xterm-256color}"
  local colorterm_value="${COLORTERM:-}"
  local ros_domain_id_value="${ROS_DOMAIN_ID:-}"
  local ros_localhost_only_value="${ROS_LOCALHOST_ONLY:-}"
  local rmw_implementation_value="${RMW_IMPLEMENTATION:-}"

  setsid env -i \
    HOME="${HOME}" \
    USER="${USER:-}" \
    LOGNAME="${LOGNAME:-}" \
    SHELL=/bin/bash \
    DISPLAY="${display_value}" \
    XAUTHORITY="${xauthority_value}" \
    XDG_RUNTIME_DIR="${xdg_runtime_dir_value}" \
    TERM="${term_value}" \
    COLORTERM="${colorterm_value}" \
    ROS_DOMAIN_ID="${ros_domain_id_value}" \
    ROS_LOCALHOST_ONLY="${ros_localhost_only_value}" \
    RMW_IMPLEMENTATION="${rmw_implementation_value}" \
    /bin/bash -lc "export PYTHONNOUSERSITE='${PYTHONNOUSERSITE}'; \
      set +u; \
      source /opt/ros/humble/setup.bash; \
      source '${OFFICIAL_ENV_DIR}/install/setup.bash'; \
      source '${CURRENT_STACK_DIR}/install/setup.bash'; \
      set -u; \
      export LD_LIBRARY_PATH='${CURRENT_STACK_DIR}/install/tare_planner/lib:'\"\${LD_LIBRARY_PATH:-}\"; \
      export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:\$PATH; \
      exec ros2 run rviz2 rviz2 -d '${RVIZ_CONFIG_FILE}'" >/dev/null 2>&1 &
  printf '%s' "$!"
}

if has_stale_processes; then
  echo "Detected stale official Gazebo/TARE processes without a pid file." >&2
  echo "Run ${ROOT_DIR}/scripts/gazebo/stop_official_tare_current_stack.sh before starting a new session." >&2
  exit 1
fi

if [[ "${START_SYSTEM}" == "1" ]]; then
  SYSTEM_PID="$(start_bg ros2 launch "${SYSTEM_LAUNCH_FILE}" \
    "world_name:=${SCENE}" \
    "gazebo_gui:=${GAZEBO_GUI}" \
    "cameraOffsetZ:=${CAMERA_OFFSET_Z}" \
    "checkTerrainConn:=${CHECK_TERRAIN_CONN}" \
    "cmd_vel_topic:=/cmd_vel_stamped" \
    "start_joy:=${START_JOY}")"
  write_pid_file
  echo "Official perception system started: pid=${SYSTEM_PID}"
fi

wait_for_topic /state_estimation 120
wait_for_topic /registered_scan 120
wait_for_topic /terrain_map 120
wait_for_topic /terrain_map_ext 120
wait_for_topic /state_estimation_at_scan 120

if [[ "${START_OCTOMAP}" == "1" ]]; then
  OCTOMAP_PID="$(start_bg ros2 run octomap_server octomap_server_node --ros-args \
    -r cloud_in:=sensor_scan \
    -p frame_id:=map \
    -p base_frame_id:=sensor \
    -p resolution:=0.2 \
    -p occupancy_min_z:=0.0 \
    -p occupancy_max_z:=1.2 \
    -p sensor_model.max_range:=20.0 \
    -p sensor_model.hit:=1.0 \
    -p sensor_model.miss:=0.45 \
    -p sensor_model.max:=1.0 \
    -p sensor_model.min:=0.2)"
  write_pid_file
  echo "octomap_server started: pid=${OCTOMAP_PID}"
fi

if [[ "${START_MONITOR}" == "1" ]]; then
  mkdir -p "${MONITOR_OUTPUT_DIR}"
  MONITOR_PID="$(start_bg python3 "${ROOT_DIR}/scripts/gazebo/monitor_xyz_trajectory.py" \
    --method "TARE_CURRENT_STACK" \
    --scene "${SCENE}" \
    --output-dir "${MONITOR_OUTPUT_DIR}" \
    --sample-period-sec "${MONITOR_SAMPLE_PERIOD_SEC}" \
    --sample-distance-m "${MONITOR_SAMPLE_DISTANCE_M}")"
  write_pid_file
  echo "Trajectory monitor started: pid=${MONITOR_PID}"
  echo "Trajectory output: ${MONITOR_OUTPUT_DIR}"
fi

activate_current_stack_env
assert_pkg_prefix local_planner
assert_pkg_prefix tare_planner

LOCAL_PLANNER_PID="$(start_bg ros2 launch local_planner local_planner.launch \
  "config:=${LOCAL_PLANNER_CONFIG}" \
  "realRobot:=false" \
  "cameraOffsetZ:=${CAMERA_OFFSET_Z}" \
  "goalX:=0.0" \
  "goalY:=0.0" \
  "maxSpeed:=${MAX_SPEED}" \
  "twoWayDrive:=${TWO_WAY_DRIVE}" \
  "autonomyMode:=true" \
  "autonomySpeed:=${AUTONOMY_SPEED}" \
  "vehicleLength:=${VEHICLE_LENGTH}" \
  "vehicleWidth:=${VEHICLE_WIDTH}" \
  "enableDebugLog:=${DEBUG_LOG_BOOL}" \
  "debugLogDir:=${DEBUG_LOG_DIR}" \
  "debugLogDecimation:=${DEBUG_LOG_DECIMATION}")"
write_pid_file
echo "Current-stack local planner started: pid=${LOCAL_PLANNER_PID}"

wait_for_topic /path 60

TARE_PID="$(start_bg ros2 run tare_planner tare_planner_node --ros-args \
  --params-file "${TARE_PARAM_FILE}" \
  -p enableDebugLog:="${DEBUG_LOG_BOOL}" \
  -p debugLogDir:="${DEBUG_LOG_DIR}" \
  -p debugLogDecimation:="${DEBUG_LOG_DECIMATION}")"
write_pid_file
echo "Current-stack TARE started: pid=${TARE_PID}"

wait_for_topic /way_point 120

if [[ "${START_RVIZ}" == "1" ]]; then
  RVIZ_PID="$(start_rviz_bg)"
  write_pid_file
  echo "RViz started: pid=${RVIZ_PID}"
  echo "RViz config: ${RVIZ_CONFIG_FILE}"
fi

echo
echo "Official Gazebo + current-stack TARE is up."
echo "Scene: ${SCENE}"
echo "TARE params: ${TARE_PARAM_FILE}"
echo "Local planner config: ${LOCAL_PLANNER_CONFIG}"
echo "Max speed: ${MAX_SPEED}"
echo "Gazebo GUI: ${GAZEBO_GUI}"
echo "Trajectory monitor: ${START_MONITOR}"
if [[ "${START_MONITOR}" == "1" ]]; then
  echo "Trajectory output: ${MONITOR_OUTPUT_DIR}"
fi
echo "Stop with Ctrl-C, or run: ${ROOT_DIR}/scripts/gazebo/stop_official_tare_current_stack.sh"
echo

while true; do
  sleep 2
done
