#!/usr/bin/env bash

set -euo pipefail

RUN_DIR="/tmp/unity_ariadne_run"
PID_FILE="${RUN_DIR}/pids.env"

if [[ ! -f "${PID_FILE}" ]]; then
  echo "No pid file found at ${PID_FILE}"
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

for pid_var in RVIZ_PID RL_PLANNER_PID OCTOMAP_PID ENDPOINT_PID ROS_LAUNCH_PID UNITY_PID; do
  pid="$(read_pid "${pid_var}")"
  if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
    echo "Stopping ${pid_var}=${pid}"
    kill -- "-${pid}" 2>/dev/null || kill "${pid}" 2>/dev/null || true
  fi
done

rm -f "${PID_FILE}"
echo "Stopped Unity + ARiADNE session"
