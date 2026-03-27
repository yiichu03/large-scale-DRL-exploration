#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

AUTONOMY_STACK_DIR="/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform"
ARIADNE_ROS_DIR="/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner"
RUN_DIR="${ARIADNE_ROS_DIR}/tmp/unity_ariadne_run"
PID_FILE="${RUN_DIR}/pids.env"

UNITY_WORLD="${UNITY_WORLD:-environment}"
SIM_LAUNCH="${SIM_LAUNCH:-system_simulation.launch}"
RESTART_ENDPOINT="${RESTART_ENDPOINT:-1}"
START_RVIZ="${START_RVIZ:-1}"
RVIZ_CONFIG="${RVIZ_CONFIG:-vehicle_simulator}"
CAPTURE_LOGS="${CAPTURE_LOGS:-0}"
OCTOMAP_RESOLUTION="${OCTOMAP_RESOLUTION:-0.4}"
OCCUPANCY_MIN_Z="${OCCUPANCY_MIN_Z:-0.0}"
OCCUPANCY_MAX_Z="${OCCUPANCY_MAX_Z:-1.2}"
OCTOMAP_SENSOR_MAX_RANGE="${OCTOMAP_SENSOR_MAX_RANGE:-20.0}"
OCTOMAP_SENSOR_HIT="${OCTOMAP_SENSOR_HIT:-1.0}"
OCTOMAP_SENSOR_MISS="${OCTOMAP_SENSOR_MISS:-0.45}"
OCTOMAP_SENSOR_MAX="${OCTOMAP_SENSOR_MAX:-1.0}"
OCTOMAP_SENSOR_MIN="${OCTOMAP_SENSOR_MIN:-0.2}"
ARIADNE_PUBLISH_GRAPH="${ARIADNE_PUBLISH_GRAPH:-true}"
ARIADNE_NODE_RESOLUTION="${ARIADNE_NODE_RESOLUTION:-2.0}"
ARIADNE_SENSOR_RANGE="${ARIADNE_SENSOR_RANGE:-20.0}"
ARIADNE_UTILITY_RANGE_FACTOR="${ARIADNE_UTILITY_RANGE_FACTOR:-0.5}"
ARIADNE_MIN_UTILITY="${ARIADNE_MIN_UTILITY:-3}"
ARIADNE_FRONTIER_DOWNSAMPLE_FACTOR="${ARIADNE_FRONTIER_DOWNSAMPLE_FACTOR:-1}"
ARIADNE_MAP_RESOLUTION="${ARIADNE_MAP_RESOLUTION:-0.4}"
ARIADNE_WAYPOINT_THRESHOLD="${ARIADNE_WAYPOINT_THRESHOLD:-2.0}"
ARIADNE_NEXT_WAYPOINT_THRESHOLD="${ARIADNE_NEXT_WAYPOINT_THRESHOLD:-4.0}"
ARIADNE_HARD_UPDATE_THRESHOLD="${ARIADNE_HARD_UPDATE_THRESHOLD:-10.0}"
ARIADNE_FRONTIER_CLUSTER_RANGE="${ARIADNE_FRONTIER_CLUSTER_RANGE:-10.0}"
ARIADNE_ENABLE_SAVE_MODE="${ARIADNE_ENABLE_SAVE_MODE:-false}"
ARIADNE_ENABLE_DSTARLITE="${ARIADNE_ENABLE_DSTARLITE:-false}"
ARIADNE_REPLANNING_FREQUENCY="${ARIADNE_REPLANNING_FREQUENCY:-2.5}"

mkdir -p "${RUN_DIR}"

if [[ -f "${PID_FILE}" ]]; then
  echo "Found existing pid file: ${PID_FILE}"
  echo "Run ${ROOT_DIR}/scripts/stop_unity_ariadne.sh first if the previous session is still active."
  exit 1
fi

if [[ ! -f "${AUTONOMY_STACK_DIR}/install/setup.bash" ]]; then
  echo "Missing autonomy_stack install/setup.bash"
  exit 1
fi

if [[ ! -f "${ARIADNE_ROS_DIR}/install/setup.bash" ]]; then
  echo "Missing ARiADNE-ROS-Planner install/setup.bash"
  exit 1
fi

UNITY_BIN="${AUTONOMY_STACK_DIR}/src/base_autonomy/vehicle_simulator/mesh/unity/${UNITY_WORLD}/Model.x86_64"

if [[ ! -x "${UNITY_BIN}" ]]; then
  echo "Unity executable not found or not executable: ${UNITY_BIN}"
  exit 1
fi

resolve_rviz_config() {
  case "${RVIZ_CONFIG}" in
    vehicle_simulator)
      RVIZ_CONFIG_PATH="${AUTONOMY_STACK_DIR}/src/base_autonomy/vehicle_simulator/rviz/vehicle_simulator.rviz"
      ;;
    ariadne)
      RVIZ_CONFIG_PATH="${ARIADNE_ROS_DIR}/src/rl_planner/rviz/rviz.rviz"
      ;;
    tare)
      RVIZ_CONFIG_PATH="${AUTONOMY_STACK_DIR}/src/exploration_planner/tare_planner/rviz/tare_planner_ground.rviz"
      ;;
    *)
      RVIZ_CONFIG_PATH="${RVIZ_CONFIG}"
      ;;
  esac
}

if [[ "${START_RVIZ}" == "1" ]]; then
  resolve_rviz_config
  if [[ ! -f "${RVIZ_CONFIG_PATH}" ]]; then
    echo "RViz config not found: ${RVIZ_CONFIG_PATH}"
    exit 1
  fi
fi

set +u
source /opt/ros/humble/setup.bash
source "${AUTONOMY_STACK_DIR}/install/setup.bash"
source "${ARIADNE_ROS_DIR}/install/setup.bash"
set -u

cleanup() {
  set +e
  if [[ -f "${PID_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${PID_FILE}"
    for pid_var in RVIZ_PID RL_PLANNER_PID OCTOMAP_PID ENDPOINT_PID ROS_LAUNCH_PID UNITY_PID; do
      pid="${!pid_var:-}"
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
      fi
    done
    rm -f "${PID_FILE}"
  fi
}

handle_signal() {
  local signal_name="${1:-INT}"
  local exit_code="${2:-130}"
  echo
  echo "Received ${signal_name}, stopping Unity + ARiADNE session..."
  cleanup
  exit "${exit_code}"
}

trap cleanup EXIT
trap 'handle_signal INT 130' INT
trap 'handle_signal TERM 143' TERM

write_pid_file() {
  cat > "${PID_FILE}" <<EOF
UNITY_PID=${UNITY_PID:-}
ROS_LAUNCH_PID=${ROS_LAUNCH_PID:-}
ENDPOINT_PID=${ENDPOINT_PID:-}
OCTOMAP_PID=${OCTOMAP_PID:-}
RL_PLANNER_PID=${RL_PLANNER_PID:-}
RVIZ_PID=${RVIZ_PID:-}
EOF
}

start_bg() {
  local name="$1"
  shift
  local output_target="/dev/null"
  if [[ "${CAPTURE_LOGS}" == "1" ]]; then
    local log_dir="${RUN_DIR}/logs"
    mkdir -p "${log_dir}"
    output_target="${log_dir}/${name}.log"
  fi
  setsid "$@" >"${output_target}" 2>&1 &
  local pid=$!
  if [[ "${CAPTURE_LOGS}" == "1" ]]; then
    echo "${name} started: pid=${pid} log=${output_target}" >&2
  else
    echo "${name} started: pid=${pid}" >&2
  fi
  printf '%s' "${pid}"
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
      echo "Timeout waiting for topic: ${topic}"
      return 1
    fi
    sleep 1
  done
}

publish_resume_navigation() {
  ros2 topic pub --once /joy sensor_msgs/msg/Joy \
    "{header: {frame_id: teleop_panel}, axes: [0.0, 0.0, -1.0, 0.0, 1.0, 1.0, 0.0, 0.0], buttons: [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0]}" \
    >/dev/null 2>&1
  echo "Published /joy message for 'Resume Navigation to Goal'"
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
    bash -lc "set +u && source /opt/ros/humble/setup.bash && source '${AUTONOMY_STACK_DIR}/install/setup.bash' && source '${ARIADNE_ROS_DIR}/install/setup.bash' && rviz2 -d '${RVIZ_CONFIG_PATH}'"
}

UNITY_PID="$(start_bg unity "${UNITY_BIN}")"
write_pid_file
sleep 3

ROS_LAUNCH_PID="$(start_bg ros_sim ros2 launch vehicle_simulator "${SIM_LAUNCH}")"
write_pid_file
sleep 8

if [[ "${RESTART_ENDPOINT}" == "1" ]]; then
  pkill -f "ros_tcp_endpoint default_server_endpoint" 2>/dev/null || true
  sleep 1
  ENDPOINT_PID="$(start_bg endpoint ros2 run ros_tcp_endpoint default_server_endpoint --ros-args -p ROS_IP:=0.0.0.0 -p ROS_TCP_PORT:=10000)"
  write_pid_file
  sleep 3
fi

wait_for_topic /state_estimation 60
wait_for_topic /sensor_scan 60

OCTOMAP_PID="$(start_bg octomap ros2 run octomap_server octomap_server_node --ros-args -r cloud_in:=sensor_scan -p frame_id:=map -p base_frame_id:=sensor_at_scan -p resolution:=${OCTOMAP_RESOLUTION} -p occupancy_min_z:=${OCCUPANCY_MIN_Z} -p occupancy_max_z:=${OCCUPANCY_MAX_Z} -p sensor_model.max_range:=${OCTOMAP_SENSOR_MAX_RANGE} -p sensor_model.hit:=${OCTOMAP_SENSOR_HIT} -p sensor_model.miss:=${OCTOMAP_SENSOR_MISS} -p sensor_model.max:=${OCTOMAP_SENSOR_MAX} -p sensor_model.min:=${OCTOMAP_SENSOR_MIN})"
write_pid_file
sleep 5

RL_PLANNER_PID="$(start_bg ariadne ros2 run rl_planner rl_planner --ros-args -p publish_graph:=${ARIADNE_PUBLISH_GRAPH} -p node_resolution:=${ARIADNE_NODE_RESOLUTION} -p sensor_range:=${ARIADNE_SENSOR_RANGE} -p utility_range_factor:=${ARIADNE_UTILITY_RANGE_FACTOR} -p min_utility:=${ARIADNE_MIN_UTILITY} -p frontier_downsample_factor:=${ARIADNE_FRONTIER_DOWNSAMPLE_FACTOR} -p map_resolution:=${ARIADNE_MAP_RESOLUTION} -p waypoint_threshold:=${ARIADNE_WAYPOINT_THRESHOLD} -p next_waypoint_threshold:=${ARIADNE_NEXT_WAYPOINT_THRESHOLD} -p hard_update_threshold:=${ARIADNE_HARD_UPDATE_THRESHOLD} -p frontier_cluster_range:=${ARIADNE_FRONTIER_CLUSTER_RANGE} -p enable_save_mode:=${ARIADNE_ENABLE_SAVE_MODE} -p enable_dstarlite:=${ARIADNE_ENABLE_DSTARLITE} -p replanning_frequency:=${ARIADNE_REPLANNING_FREQUENCY})"
write_pid_file

wait_for_topic /projected_map 60
wait_for_topic /way_point 60

if [[ "${START_RVIZ}" == "1" ]]; then
  RVIZ_PID="$(start_rviz)"
  write_pid_file
  sleep 2
fi

publish_resume_navigation

echo
echo "Unity + ARiADNE integration is up."
if [[ "${START_RVIZ}" == "1" ]]; then
  echo "RViz config: ${RVIZ_CONFIG_PATH}"
fi
if [[ "${CAPTURE_LOGS}" == "1" ]]; then
  echo "Logs: ${RUN_DIR}/logs"
fi
echo "Stop with Ctrl-C, or run: ${ROOT_DIR}/scripts/stop_unity_ariadne.sh"
echo

while true; do
  sleep 2
done
