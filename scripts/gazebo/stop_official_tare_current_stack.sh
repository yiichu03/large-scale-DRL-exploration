#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THERMAL_NAV_DIR="$(dirname "${ROOT_DIR}")"
OFFICIAL_ENV_DIR="${OFFICIAL_ENV_DIR:-${THERMAL_NAV_DIR}/autonomous_exploration_development_environment}"
CURRENT_STACK_DIR="${CURRENT_STACK_DIR:-${THERMAL_NAV_DIR}/autonomy_stack_mecanum_wheel_platform}"
RUN_DIR="${RUN_DIR:-${ROOT_DIR}/tmp/official_gazebo_tare_current_stack_run}"
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
  kill_matches "${OFFICIAL_ENV_DIR}/install/vehicle_simulator/lib/vehicle_simulator/vehicleSimulator"
  kill_matches "${OFFICIAL_ENV_DIR}/install/sensor_scan_generation/lib/sensor_scan_generation/sensorScanGeneration"
  kill_matches "${OFFICIAL_ENV_DIR}/install/terrain_analysis/lib/terrain_analysis/terrainAnalysis"
  kill_matches "${OFFICIAL_ENV_DIR}/install/terrain_analysis_ext/lib/terrain_analysis_ext/terrainAnalysisExt"
  kill_matches '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /vehicle'
  kill_matches '/opt/ros/humble/lib/tf2_ros/static_transform_publisher .* /sensor /camera'
  kill_matches '/opt/ros/humble/lib/robot_state_publisher/robot_state_publisher'
  kill_matches "${ROOT_DIR}/scripts/gazebo/launch/official_system_perception_no_xacro.launch.py"
}

if [[ ! -f "${PID_FILE}" ]]; then
  echo "No pid file found at ${PID_FILE}"
  echo "Falling back to process-pattern shutdown"

  kill_matches "${ROOT_DIR}/scripts/gazebo/launch_official_tare_current_stack.sh"
  kill_matches "${ROOT_DIR}/scripts/gazebo/monitor_xyz_trajectory.py"
  kill_matches "${ROOT_DIR}/scripts/gazebo/launch/official_system_perception_no_xacro.launch.py"
  kill_matches '/opt/ros/humble/bin/ros2 launch local_planner local_planner.launch'
  kill_matches "${CURRENT_STACK_DIR}/install/local_planner/lib/local_planner/localPlanner"
  kill_matches "${CURRENT_STACK_DIR}/install/local_planner/lib/local_planner/pathFollower"
  kill_matches '/opt/ros/humble/bin/ros2 run tare_planner tare_planner_node'
  kill_matches "${CURRENT_STACK_DIR}/install/tare_planner/lib/tare_planner/tare_planner_node"
  kill_matches 'gzserver .*vehicle_simulator/world/.*\.world'
  kill_matches 'gzclient --gui-client-plugin=libgazebo_ros_eol_gui.so'
  kill_matches '/opt/ros/humble/lib/rviz2/rviz2'
  kill_official_system_processes

  echo "Stopped official Gazebo + current-stack TARE session (fallback mode)"
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

for pid_var in RVIZ_PID MONITOR_PID TARE_PID LOCAL_PLANNER_PID SYSTEM_PID; do
  pid="$(read_pid "${pid_var}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    echo "Stopping ${pid_var}=${pid}"
    kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
  fi
done

kill_matches "${ROOT_DIR}/scripts/gazebo/launch_official_tare_current_stack.sh"
kill_matches "${ROOT_DIR}/scripts/gazebo/monitor_xyz_trajectory.py"
kill_matches "${ROOT_DIR}/scripts/gazebo/launch/official_system_perception_no_xacro.launch.py"
kill_matches '/opt/ros/humble/bin/ros2 launch local_planner local_planner.launch'
kill_matches "${CURRENT_STACK_DIR}/install/local_planner/lib/local_planner/localPlanner"
kill_matches "${CURRENT_STACK_DIR}/install/local_planner/lib/local_planner/pathFollower"
kill_matches '/opt/ros/humble/bin/ros2 run tare_planner tare_planner_node'
kill_matches "${CURRENT_STACK_DIR}/install/tare_planner/lib/tare_planner/tare_planner_node"
kill_matches 'gzserver .*vehicle_simulator/world/.*\.world'
kill_matches 'gzclient --gui-client-plugin=libgazebo_ros_eol_gui.so'
kill_matches '/opt/ros/humble/lib/rviz2/rviz2'
kill_official_system_processes

rm -f "${PID_FILE}"
echo "Stopped official Gazebo + current-stack TARE session"
