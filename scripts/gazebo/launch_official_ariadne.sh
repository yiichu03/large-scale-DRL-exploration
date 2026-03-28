#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THERMAL_NAV_DIR="$(dirname "${ROOT_DIR}")"
OFFICIAL_ENV_DIR="${OFFICIAL_ENV_DIR:-${THERMAL_NAV_DIR}/autonomous_exploration_development_environment}"
ARIADNE_ROS_DIR="${ARIADNE_ROS_DIR:-/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner}"
SYSTEM_LAUNCH_FILE="${SYSTEM_LAUNCH_FILE:-${ROOT_DIR}/scripts/gazebo/launch/official_system_no_xacro.launch.py}"
RVIZ_CONFIG_FILE="${RVIZ_CONFIG_FILE:-${ROOT_DIR}/scripts/gazebo/rviz/official_gazebo_ariadne_clean.rviz}"
RUN_DIR="${RUN_DIR:-${ARIADNE_ROS_DIR}/tmp/official_gazebo_ariadne_run}"
PID_FILE="${RUN_DIR}/pids.env"

START_SYSTEM="${START_SYSTEM:-0}"
SCENE="${SCENE:-indoor}"
GAZEBO_GUI="${GAZEBO_GUI:-false}"
START_RVIZ="${START_RVIZ:-0}"
USE_ARIADNE_CONDA="${USE_ARIADNE_CONDA:-1}"
ARIADNE_CONDA_ENV="${ARIADNE_CONDA_ENV:-ros2-torch}"
ARIADNE_CONDA_SH="${ARIADNE_CONDA_SH:-/home/liuyi/miniforge3/etc/profile.d/conda.sh}"

BASE_FRAME="${BASE_FRAME:-sensor}"
SENSOR_RANGE="${SENSOR_RANGE:-20.0}"
MAP_RESOLUTION="${MAP_RESOLUTION:-0.4}"
NODE_RESOLUTION="${NODE_RESOLUTION:-2.0}"
PUBLISH_GRAPH="${PUBLISH_GRAPH:-false}"
UTILITY_RANGE_FACTOR="${UTILITY_RANGE_FACTOR:-0.5}"
MIN_UTILITY="${MIN_UTILITY:-3}"
FRONTIER_DOWNSAMPLE_FACTOR="${FRONTIER_DOWNSAMPLE_FACTOR:-1}"
WAYPOINT_THRESHOLD="${WAYPOINT_THRESHOLD:-2.0}"
NEXT_WAYPOINT_THRESHOLD="${NEXT_WAYPOINT_THRESHOLD:-4.0}"
HARD_UPDATE_THRESHOLD="${HARD_UPDATE_THRESHOLD:-10.0}"
FRONTIER_CLUSTER_RANGE="${FRONTIER_CLUSTER_RANGE:-10.0}"
ENABLE_SAVE_MODE="${ENABLE_SAVE_MODE:-false}"
ENABLE_DSTARLITE="${ENABLE_DSTARLITE:-false}"
REPLANNING_FREQUENCY="${REPLANNING_FREQUENCY:-2.5}"

if [[ ! -f /opt/ros/humble/setup.bash ]]; then
  echo "Missing ROS2 Humble setup: /opt/ros/humble/setup.bash" >&2
  exit 1
fi

if [[ ! -f "${OFFICIAL_ENV_DIR}/install/setup.bash" ]]; then
  echo "Missing official environment install/setup.bash: ${OFFICIAL_ENV_DIR}/install/setup.bash" >&2
  echo "Build the official workspace first." >&2
  exit 1
fi

if [[ ! -f "${ARIADNE_ROS_DIR}/install/setup.bash" ]]; then
  echo "Missing ARiADNE install/setup.bash: ${ARIADNE_ROS_DIR}/install/setup.bash" >&2
  exit 1
fi

if [[ ! -f "${RVIZ_CONFIG_FILE}" ]]; then
  echo "Missing RViz config: ${RVIZ_CONFIG_FILE}" >&2
  exit 1
fi

if [[ "${USE_ARIADNE_CONDA}" == "1" && ! -f "${ARIADNE_CONDA_SH}" ]]; then
  echo "Missing conda setup script: ${ARIADNE_CONDA_SH}" >&2
  exit 1
fi

mkdir -p "${RUN_DIR}"

if [[ -f "${PID_FILE}" ]]; then
  echo "Found existing pid file: ${PID_FILE}" >&2
  echo "Run ${ROOT_DIR}/scripts/gazebo/stop_official_ariadne.sh first if the previous session is still active." >&2
  exit 1
fi

cleanup() {
  set +e
  for pid in "${RL_PLANNER_PID:-}" "${OCTOMAP_PID:-}" "${SYSTEM_PID:-}" "${RVIZ_PID:-}"; do
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
      kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
    fi
  done
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
export GAZEBO_HOME="${GAZEBO_HOME:-/tmp/gazebo_home}"
export ROS_LOG_DIR="${ROS_LOG_DIR:-/tmp/roslogs_official_ariadne}"
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
    '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/vehicle_simulator/lib/vehicle_simulator/vehicleSimulator'
    '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/sensor_scan_generation/lib/sensor_scan_generation/sensorScanGeneration'
    '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/terrain_analysis/lib/terrain_analysis/terrainAnalysis'
    '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/terrain_analysis_ext/lib/terrain_analysis_ext/terrainAnalysisExt'
    '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /vehicle'
    '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /camera'
    '/opt/ros/humble/lib/robot_state_publisher/robot_state_publisher'
    'gzserver .*vehicle_simulator/world/.*\.world'
    'gzclient --gui-client-plugin=libgazebo_ros_eol_gui.so'
  )
  local pattern
  for pattern in "${patterns[@]}"; do
    if pgrep -f "${pattern}" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
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
      source '${ARIADNE_ROS_DIR}/install/setup.bash'; \
      set -u; \
      export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:\$PATH; \
      exec ros2 run rviz2 rviz2 -d '${RVIZ_CONFIG_FILE}'" >/dev/null 2>&1 &
  printf '%s' "$!"
}

write_pid_file() {
  cat > "${PID_FILE}" <<EOF
SYSTEM_PID=${SYSTEM_PID:-}
OCTOMAP_PID=${OCTOMAP_PID:-}
RL_PLANNER_PID=${RL_PLANNER_PID:-}
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

activate_ariadne_env() {
  if [[ "${USE_ARIADNE_CONDA}" == "1" ]]; then
    set +u
    source "${ARIADNE_CONDA_SH}"
    conda activate "${ARIADNE_CONDA_ENV}"
    set -u
    echo "Activated conda env: ${ARIADNE_CONDA_ENV}"
  fi

  set +u
  source /opt/ros/humble/setup.bash
  source "${OFFICIAL_ENV_DIR}/install/setup.bash"
  source "${ARIADNE_ROS_DIR}/install/setup.bash"
  set -u
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:${PATH}"
}

if has_stale_processes; then
  echo "Detected stale official Gazebo system processes without a pid file." >&2
  echo "Run ${ROOT_DIR}/scripts/gazebo/stop_official_ariadne.sh before starting a new session." >&2
  exit 1
fi

if [[ "${START_SYSTEM}" == "1" ]]; then
  SYSTEM_PID="$(start_bg ros2 launch "${SYSTEM_LAUNCH_FILE}" "world_name:=${SCENE}" "gazebo_gui:=${GAZEBO_GUI}")"
  write_pid_file
  echo "Official system started: pid=${SYSTEM_PID}"
fi

wait_for_topic /state_estimation 120
wait_for_topic /sensor_scan 120
activate_ariadne_env

OCTOMAP_PID="$(start_bg ros2 run octomap_server octomap_server_node --ros-args \
  -r cloud_in:=sensor_scan \
  -p frame_id:=map \
  -p base_frame_id:=${BASE_FRAME} \
  -p resolution:=${MAP_RESOLUTION} \
  -p occupancy_min_z:=0.0 \
  -p occupancy_max_z:=1.2 \
  -p sensor_model.max_range:=${SENSOR_RANGE} \
  -p sensor_model.hit:=1.0 \
  -p sensor_model.miss:=0.45 \
  -p sensor_model.max:=1.0 \
  -p sensor_model.min:=0.2)"
write_pid_file
echo "octomap started: pid=${OCTOMAP_PID}"

wait_for_topic /projected_map 120

RL_PLANNER_PID="$(start_bg ros2 run rl_planner rl_planner --ros-args \
  -p publish_graph:=${PUBLISH_GRAPH} \
  -p node_resolution:=${NODE_RESOLUTION} \
  -p sensor_range:=${SENSOR_RANGE} \
  -p utility_range_factor:=${UTILITY_RANGE_FACTOR} \
  -p min_utility:=${MIN_UTILITY} \
  -p frontier_downsample_factor:=${FRONTIER_DOWNSAMPLE_FACTOR} \
  -p map_resolution:=${MAP_RESOLUTION} \
  -p waypoint_threshold:=${WAYPOINT_THRESHOLD} \
  -p next_waypoint_threshold:=${NEXT_WAYPOINT_THRESHOLD} \
  -p hard_update_threshold:=${HARD_UPDATE_THRESHOLD} \
  -p frontier_cluster_range:=${FRONTIER_CLUSTER_RANGE} \
  -p enable_save_mode:=${ENABLE_SAVE_MODE} \
  -p enable_dstarlite:=${ENABLE_DSTARLITE} \
  -p replanning_frequency:=${REPLANNING_FREQUENCY})"
write_pid_file
echo "rl_planner started: pid=${RL_PLANNER_PID}"

wait_for_topic /way_point 120

if [[ "${START_RVIZ}" == "1" ]]; then
  RVIZ_PID="$(start_rviz_bg)"
  write_pid_file
  echo "RViz started: pid=${RVIZ_PID}"
  echo "RViz config: ${RVIZ_CONFIG_FILE}"
fi

echo
echo "Official Gazebo + ARiADNE is up."
echo "Scene: ${SCENE}"
echo "Base frame: ${BASE_FRAME}"
echo "Gazebo GUI: ${GAZEBO_GUI}"
echo "Stop with Ctrl-C, or run: ${ROOT_DIR}/scripts/gazebo/stop_official_ariadne.sh"
echo

while true; do
  sleep 2
done
