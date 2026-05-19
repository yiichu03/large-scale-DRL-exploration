#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Keep this wrapper thin: it only selects the QR_SimEval test3 world and
# disables the built-in scene whitelist so the main launcher stays unchanged.
export SCENE="${SCENE:-qr_test3_maze}"
export SCENE_PRESET="${SCENE_PRESET:-none}"
export START_SYSTEM="${START_SYSTEM:-1}"
export GAZEBO_GUI="${GAZEBO_GUI:-false}"

exec "${ROOT_DIR}/scripts/gazebo/launch_official_ariadne.sh"
