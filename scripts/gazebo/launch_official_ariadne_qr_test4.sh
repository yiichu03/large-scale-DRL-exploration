#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THERMAL_NAV_DIR="$(dirname "${ROOT_DIR}")"
QR_MODELS_DIR="${QR_MODELS_DIR:-${THERMAL_NAV_DIR}/archive/QR_SimEval_Code/gazebo_models}"

if [[ ! -d "${QR_MODELS_DIR}" ]]; then
  echo "Missing QR Gazebo models directory: ${QR_MODELS_DIR}" >&2
  exit 1
fi

# Keep this wrapper thin: it only selects the QR_SimEval test4 world,
# disables the built-in scene whitelist, and exposes the QR model library.
export GAZEBO_MODEL_PATH="${QR_MODELS_DIR}:${GAZEBO_MODEL_PATH:-}"
export SCENE="${SCENE:-qr_test4_neighborhood}"
export SCENE_PRESET="${SCENE_PRESET:-none}"
export START_SYSTEM="${START_SYSTEM:-1}"
export GAZEBO_GUI="${GAZEBO_GUI:-false}"

exec "${ROOT_DIR}/scripts/gazebo/launch_official_ariadne.sh"
