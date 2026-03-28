#!/usr/bin/env bash

set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-/spawn_entity}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-240}"

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <spawn_entity.py args...>" >&2
  exit 2
fi

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ros2 command not found in PATH" >&2
  exit 1
fi

if [[ ! -x /opt/ros/humble/lib/gazebo_ros/spawn_entity.py ]]; then
  echo "spawn_entity.py not found: /opt/ros/humble/lib/gazebo_ros/spawn_entity.py" >&2
  exit 1
fi

export PYTHONNOUSERSITE="${PYTHONNOUSERSITE:-1}"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/ros/humble/bin:${PATH}"

start_sec="$(date +%s)"
while true; do
  if ros2 service type "${SERVICE_NAME}" >/dev/null 2>&1; then
    break
  fi

  now_sec="$(date +%s)"
  if (( now_sec - start_sec >= WAIT_TIMEOUT_SEC )); then
    echo "Timeout waiting for service ${SERVICE_NAME}" >&2
    exit 1
  fi

  sleep 2
done

exec /opt/ros/humble/lib/gazebo_ros/spawn_entity.py "$@"
