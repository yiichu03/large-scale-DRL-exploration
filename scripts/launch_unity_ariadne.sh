#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

AUTONOMY_STACK_DIR="/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform"
ARIADNE_ROS_DIR="/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner"
RUN_DIR="/tmp/unity_ariadne_run"
LOG_DIR="${RUN_DIR}/logs"
PID_FILE="${RUN_DIR}/pids.env"

UNITY_WORLD="${UNITY_WORLD:-environment}"
SIM_LAUNCH="${SIM_LAUNCH:-system_simulation.launch}"
RESTART_ENDPOINT="${RESTART_ENDPOINT:-1}"

mkdir -p "${LOG_DIR}"

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

set +u
source /opt/ros/humble/setup.bash
source "${AUTONOMY_STACK_DIR}/install/setup.bash"
source "${ARIADNE_ROS_DIR}/install/setup.bash"
set -u

declare -a PIDS=()

cleanup() {
  set +e
  if [[ -f "${PID_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${PID_FILE}"
    for pid_var in RL_PLANNER_PID OCTOMAP_PID ENDPOINT_PID ROS_LAUNCH_PID UNITY_PID; do
      pid="${!pid_var:-}"
      if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
      fi
    done
    rm -f "${PID_FILE}"
  fi
}

trap cleanup EXIT INT TERM

write_pid_file() {
  cat > "${PID_FILE}" <<EOF
UNITY_PID=${UNITY_PID:-}
ROS_LAUNCH_PID=${ROS_LAUNCH_PID:-}
ENDPOINT_PID=${ENDPOINT_PID:-}
OCTOMAP_PID=${OCTOMAP_PID:-}
RL_PLANNER_PID=${RL_PLANNER_PID:-}
EOF
}

start_bg() {
  local name="$1"
  shift
  local log_file="${LOG_DIR}/${name}.log"
  setsid "$@" >"${log_file}" 2>&1 &
  local pid=$!
  echo "${name} started: pid=${pid} log=${log_file}" >&2
  PIDS+=("${pid}")
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

UNITY_PID="$(start_bg unity env ROS_LOG_DIR="${RUN_DIR}/unity_logs" "${UNITY_BIN}")"
write_pid_file
sleep 3

ROS_LAUNCH_PID="$(start_bg ros_sim env ROS_LOG_DIR="${RUN_DIR}/ros_sim_logs" ros2 launch vehicle_simulator "${SIM_LAUNCH}")"
write_pid_file
sleep 8

if [[ "${RESTART_ENDPOINT}" == "1" ]]; then
  pkill -f "ros_tcp_endpoint default_server_endpoint" 2>/dev/null || true
  sleep 1
  ENDPOINT_PID="$(start_bg endpoint env ROS_LOG_DIR="${RUN_DIR}/endpoint_logs" ros2 run ros_tcp_endpoint default_server_endpoint --ros-args -p ROS_IP:=0.0.0.0 -p ROS_TCP_PORT:=10000)"
  write_pid_file
  sleep 3
fi

wait_for_topic /state_estimation 60
wait_for_topic /sensor_scan 60

OCTOMAP_PID="$(start_bg octomap env ROS_LOG_DIR="${RUN_DIR}/octomap_logs" ros2 run octomap_server octomap_server_node --ros-args -r cloud_in:=sensor_scan -p frame_id:=map -p base_frame_id:=sensor_at_scan -p resolution:=0.4 -p occupancy_min_z:=0.0 -p occupancy_max_z:=1.2 -p sensor_model.max_range:=20.0 -p sensor_model.hit:=1.0 -p sensor_model.miss:=0.45 -p sensor_model.max:=1.0 -p sensor_model.min:=0.2)"
write_pid_file
sleep 5

RL_PLANNER_PID="$(start_bg ariadne env ROS_LOG_DIR="${RUN_DIR}/ariadne_logs" ros2 run rl_planner rl_planner --ros-args -p publish_graph:=true -p node_resolution:=2.0 -p sensor_range:=20.0 -p utility_range_factor:=0.5 -p min_utility:=3 -p frontier_downsample_factor:=1 -p map_resolution:=0.4 -p waypoint_threshold:=2.0 -p next_waypoint_threshold:=4.0 -p hard_update_threshold:=10.0 -p frontier_cluster_range:=10.0 -p enable_save_mode:=false -p enable_dstarlite:=false -p replanning_frequency:=2.5)"
write_pid_file

wait_for_topic /projected_map 60
wait_for_topic /way_point 60

publish_resume_navigation

echo
echo "Unity + ARiADNE integration is up."
echo "Logs: ${LOG_DIR}"
echo "Stop with Ctrl-C, or run: ${ROOT_DIR}/scripts/stop_unity_ariadne.sh"
echo

while true; do
  sleep 2
done
