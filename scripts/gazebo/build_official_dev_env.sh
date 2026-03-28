#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THERMAL_NAV_DIR="$(dirname "${ROOT_DIR}")"
OFFICIAL_ENV_DIR="${OFFICIAL_ENV_DIR:-${THERMAL_NAV_DIR}/autonomous_exploration_development_environment}"

if [[ ! -f /opt/ros/humble/setup.bash ]]; then
  echo "Missing ROS2 Humble setup: /opt/ros/humble/setup.bash" >&2
  exit 1
fi

if [[ ! -d "${OFFICIAL_ENV_DIR}" ]]; then
  echo "Official environment repo not found: ${OFFICIAL_ENV_DIR}" >&2
  exit 1
fi

set +u
source /opt/ros/humble/setup.bash
set -u

cd "${OFFICIAL_ENV_DIR}"
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
