#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THERMAL_NAV_DIR="$(dirname "${ROOT_DIR}")"
OFFICIAL_ENV_DIR="${OFFICIAL_ENV_DIR:-${THERMAL_NAV_DIR}/autonomous_exploration_development_environment}"
MODEL_SRC_DIR="${MODEL_SRC_DIR:-/home/liuyi/Downloads/autonomous_exploration_environments}"
MODEL_DST_DIR="${MODEL_DST_DIR:-${OFFICIAL_ENV_DIR}/src/vehicle_simulator/mesh}"

models=(campus forest garage indoor tunnel)

if [[ ! -d "${OFFICIAL_ENV_DIR}" ]]; then
  echo "Official environment repo not found: ${OFFICIAL_ENV_DIR}" >&2
  exit 1
fi

if [[ ! -d "${MODEL_SRC_DIR}" ]]; then
  echo "Model source directory not found: ${MODEL_SRC_DIR}" >&2
  exit 1
fi

mkdir -p "${MODEL_DST_DIR}"

for model in "${models[@]}"; do
  src="${MODEL_SRC_DIR}/${model}"
  dst="${MODEL_DST_DIR}/${model}"

  if [[ ! -d "${src}" ]]; then
    echo "Missing model directory: ${src}" >&2
    exit 1
  fi

  if [[ -L "${dst}" ]]; then
    target="$(readlink -f "${dst}")"
    expected="$(readlink -f "${src}")"
    if [[ "${target}" == "${expected}" ]]; then
      echo "OK: ${dst} -> ${target}"
      continue
    fi
    echo "Existing symlink points elsewhere: ${dst} -> ${target}" >&2
    exit 1
  fi

  if [[ -e "${dst}" ]]; then
    echo "Destination already exists and is not a symlink: ${dst}" >&2
    exit 1
  fi

  ln -s "${src}" "${dst}"
  echo "Linked: ${dst} -> ${src}"
done
