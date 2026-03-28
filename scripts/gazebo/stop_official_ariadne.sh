#!/usr/bin/env bash

set -euo pipefail

ARIADNE_ROS_DIR="${ARIADNE_ROS_DIR:-/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner}"
RUN_DIR="${RUN_DIR:-${ARIADNE_ROS_DIR}/tmp/official_gazebo_ariadne_run}"
PID_FILE="${RUN_DIR}/pids.env"

kill_matches() {
  local pattern="$1"
  local pid
  while read -r pid; do
    [[ -z "${pid}" ]] && continue
    [[ "${pid}" == "$$" ]] && continue
    local pgid
    pgid="$(ps -o pgid= -p "${pid}" 2>/dev/null | tr -d ' ' || true)"
    if [[ -n "${pgid}" ]]; then
      echo "Stopping pgid=${pgid} from pattern: ${pattern}"
      kill -- "-${pgid}" 2>/dev/null || true
      if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null || true
      fi
    else
      echo "Stopping pid=${pid} from pattern: ${pattern}"
      kill "${pid}" 2>/dev/null || true
    fi
  done < <(pgrep -f "${pattern}" || true)
}

kill_official_system_processes() {
  kill_matches '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/vehicle_simulator/lib/vehicle_simulator/vehicleSimulator'
  kill_matches '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/sensor_scan_generation/lib/sensor_scan_generation/sensorScanGeneration'
  kill_matches '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/terrain_analysis/lib/terrain_analysis/terrainAnalysis'
  kill_matches '/home/liuyi/projects/thermal_nav/autonomous_exploration_development_environment/install/terrain_analysis_ext/lib/terrain_analysis_ext/terrainAnalysisExt'
  kill_matches '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /vehicle'
  kill_matches '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /camera'
  kill_matches '/opt/ros/humble/lib/robot_state_publisher/robot_state_publisher'
  kill_matches '/opt/ros/humble/bin/ros2 launch /home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_system_no_xacro.launch.py'
}

if [[ ! -f "${PID_FILE}" ]]; then
  echo "No pid file found at ${PID_FILE}"
  echo "Falling back to process-pattern shutdown"

  kill_matches '/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_system_no_xacro.launch.py'
  kill_matches '/opt/ros/humble/bin/ros2 run octomap_server octomap_server_node'
  kill_matches '/opt/ros/humble/lib/octomap_server/octomap_server_node'
  kill_matches '/opt/ros/humble/bin/ros2 run rl_planner rl_planner'
  kill_matches '/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/rl_planner/lib/rl_planner/rl_planner'
  kill_matches 'gzserver .*vehicle_simulator/world/.*\.world'
  kill_matches 'gzclient --gui-client-plugin=libgazebo_ros_eol_gui.so'
  kill_official_system_processes

  echo "Stopped official Gazebo + ARiADNE session (fallback mode)"
  exit 0
fi

read_pid() {
  local pid_var="$1"
  local pid
  pid="$(grep -E "^${pid_var}=" "${PID_FILE}" | head -n1 | cut -d= -f2- || true)"
  if [[ "${pid}" =~ ^[0-9]+$ ]]; then
    printf '%s' "${pid}"
  fi
}

for pid_var in RVIZ_PID RL_PLANNER_PID OCTOMAP_PID SYSTEM_PID; do
  pid="$(read_pid "${pid_var}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    echo "Stopping ${pid_var}=${pid}"
    kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
  fi
done

kill_matches '/home/liuyi/projects/thermal_nav/large-scale-DRL-exploration/scripts/gazebo/launch/official_system_no_xacro.launch.py'
kill_matches '/opt/ros/humble/bin/ros2 run octomap_server octomap_server_node'
kill_matches '/opt/ros/humble/lib/octomap_server/octomap_server_node'
kill_matches '/opt/ros/humble/bin/ros2 run rl_planner rl_planner'
kill_matches '/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner/install/rl_planner/lib/rl_planner/rl_planner'
kill_matches 'gzserver .*vehicle_simulator/world/.*\.world'
kill_matches 'gzclient --gui-client-plugin=libgazebo_ros_eol_gui.so'
kill_official_system_processes

rm -f "${PID_FILE}"
echo "Stopped official Gazebo + ARiADNE session"
