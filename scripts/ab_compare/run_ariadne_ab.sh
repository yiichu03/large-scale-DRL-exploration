#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUTONOMY_STACK_DIR="/home/liuyi/projects/thermal_nav/autonomy_stack_mecanum_wheel_platform"
ARIADNE_ROS_DIR="/home/liuyi/projects/thermal_nav/ARiADNE-ROS-Planner"

SCENE_LABEL="${SCENE_LABEL:-${SCENE:-${UNITY_WORLD:-environment}}}"
UNITY_WORLD_NAME="${UNITY_WORLD:-environment}"
ARIADNE_CONFIG_TAG="${ARIADNE_CONFIG_TAG:-default}"
RUN_TAG="$(date +%Y%m%d_%H%M%S)_ariadne_${ARIADNE_CONFIG_TAG}_${SCENE_LABEL}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/ab_runs/${RUN_TAG}}"
MONITOR_PYTHON="${MONITOR_PYTHON:-/usr/bin/python3}"
START_RVIZ="${START_RVIZ:-1}"
CAPTURE_LOGS="${CAPTURE_LOGS:-0}"
AUTO_STOP_ON_FINISH="${AUTO_STOP_ON_FINISH:-1}"
FINISH_GRACE_SEC="${FINISH_GRACE_SEC:-20}"
RUN_TIMEOUT_SEC="${RUN_TIMEOUT_SEC:-0}"
LAUNCH_PID=""
AB_RUNNER_SCRIPT="${SCRIPT_DIR}/run_ariadne_ab.sh"
RUNTIME_LAUNCHER_SCRIPT="${ROOT_DIR}/scripts/launch_unity_ariadne.sh"
MONITOR_SCRIPT="${ROOT_DIR}/scripts/ab_compare/monitor_experiment.py"
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
OCTOMAP_RESOLUTION="${OCTOMAP_RESOLUTION:-0.4}"
OCCUPANCY_MIN_Z="${OCCUPANCY_MIN_Z:-0.0}"
OCCUPANCY_MAX_Z="${OCCUPANCY_MAX_Z:-1.2}"
OCTOMAP_SENSOR_MAX_RANGE="${OCTOMAP_SENSOR_MAX_RANGE:-20.0}"

git_commit() {
  local repo_dir="$1"
  git -C "${repo_dir}" rev-parse --short HEAD 2>/dev/null || printf 'unknown'
}

write_metadata() {
  cat > "${OUTPUT_DIR}/run_metadata.json" <<EOF
{
  "method": "ARIADNE",
  "scene_label": "${SCENE_LABEL}",
  "unity_world": "${UNITY_WORLD_NAME}",
  "run_tag": "${RUN_TAG}",
  "output_dir": "${OUTPUT_DIR}",
  "ab_runner_script": "${AB_RUNNER_SCRIPT}",
  "runtime_launcher_script": "${RUNTIME_LAUNCHER_SCRIPT}",
  "monitor_script": "${MONITOR_SCRIPT}",
  "planner_config_tag": "${ARIADNE_CONFIG_TAG}",
  "start_rviz": "${START_RVIZ}",
  "capture_logs": "${CAPTURE_LOGS}",
  "auto_stop_on_finish": "${AUTO_STOP_ON_FINISH}",
  "finish_grace_sec": "${FINISH_GRACE_SEC}",
  "run_timeout_sec": "${RUN_TIMEOUT_SEC}",
  "planner_params": {
    "publish_graph": "${ARIADNE_PUBLISH_GRAPH}",
    "node_resolution": "${ARIADNE_NODE_RESOLUTION}",
    "sensor_range": "${ARIADNE_SENSOR_RANGE}",
    "utility_range_factor": "${ARIADNE_UTILITY_RANGE_FACTOR}",
    "min_utility": "${ARIADNE_MIN_UTILITY}",
    "frontier_downsample_factor": "${ARIADNE_FRONTIER_DOWNSAMPLE_FACTOR}",
    "map_resolution": "${ARIADNE_MAP_RESOLUTION}",
    "waypoint_threshold": "${ARIADNE_WAYPOINT_THRESHOLD}",
    "next_waypoint_threshold": "${ARIADNE_NEXT_WAYPOINT_THRESHOLD}",
    "hard_update_threshold": "${ARIADNE_HARD_UPDATE_THRESHOLD}",
    "frontier_cluster_range": "${ARIADNE_FRONTIER_CLUSTER_RANGE}",
    "enable_save_mode": "${ARIADNE_ENABLE_SAVE_MODE}",
    "enable_dstarlite": "${ARIADNE_ENABLE_DSTARLITE}",
    "replanning_frequency": "${ARIADNE_REPLANNING_FREQUENCY}"
  },
  "octomap_params": {
    "resolution": "${OCTOMAP_RESOLUTION}",
    "occupancy_min_z": "${OCCUPANCY_MIN_Z}",
    "occupancy_max_z": "${OCCUPANCY_MAX_Z}",
    "sensor_max_range": "${OCTOMAP_SENSOR_MAX_RANGE}"
  },
  "git_commits": {
    "large_scale_drl_exploration": "$(git_commit "${ROOT_DIR}")",
    "autonomy_stack_mecanum_wheel_platform": "$(git_commit "${AUTONOMY_STACK_DIR}")",
    "ARiADNE_ROS_Planner": "$(git_commit "${ARIADNE_ROS_DIR}")"
  }
}
EOF
}

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
write_metadata

(
  cd "${ROOT_DIR}"
  START_RVIZ="${START_RVIZ}" \
  CAPTURE_LOGS="${CAPTURE_LOGS}" \
  OCTOMAP_RESOLUTION="${OCTOMAP_RESOLUTION}" \
  OCCUPANCY_MIN_Z="${OCCUPANCY_MIN_Z}" \
  OCCUPANCY_MAX_Z="${OCCUPANCY_MAX_Z}" \
  OCTOMAP_SENSOR_MAX_RANGE="${OCTOMAP_SENSOR_MAX_RANGE}" \
  ARIADNE_PUBLISH_GRAPH="${ARIADNE_PUBLISH_GRAPH}" \
  ARIADNE_NODE_RESOLUTION="${ARIADNE_NODE_RESOLUTION}" \
  ARIADNE_SENSOR_RANGE="${ARIADNE_SENSOR_RANGE}" \
  ARIADNE_UTILITY_RANGE_FACTOR="${ARIADNE_UTILITY_RANGE_FACTOR}" \
  ARIADNE_MIN_UTILITY="${ARIADNE_MIN_UTILITY}" \
  ARIADNE_FRONTIER_DOWNSAMPLE_FACTOR="${ARIADNE_FRONTIER_DOWNSAMPLE_FACTOR}" \
  ARIADNE_MAP_RESOLUTION="${ARIADNE_MAP_RESOLUTION}" \
  ARIADNE_WAYPOINT_THRESHOLD="${ARIADNE_WAYPOINT_THRESHOLD}" \
  ARIADNE_NEXT_WAYPOINT_THRESHOLD="${ARIADNE_NEXT_WAYPOINT_THRESHOLD}" \
  ARIADNE_HARD_UPDATE_THRESHOLD="${ARIADNE_HARD_UPDATE_THRESHOLD}" \
  ARIADNE_FRONTIER_CLUSTER_RANGE="${ARIADNE_FRONTIER_CLUSTER_RANGE}" \
  ARIADNE_ENABLE_SAVE_MODE="${ARIADNE_ENABLE_SAVE_MODE}" \
  ARIADNE_ENABLE_DSTARLITE="${ARIADNE_ENABLE_DSTARLITE}" \
  ARIADNE_REPLANNING_FREQUENCY="${ARIADNE_REPLANNING_FREQUENCY}" \
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
  "${MONITOR_PYTHON}" "${MONITOR_SCRIPT}"
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
