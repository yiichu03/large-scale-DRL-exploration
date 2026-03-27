#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export TARE_CONFIG="${TARE_CONFIG:-original_outdoor}"
export TARE_LAUNCHER_SCRIPT="${SCRIPT_DIR}/run_tare_outdoor_ab.sh"

exec "${SCRIPT_DIR}/run_tare_ab.sh" "$@"
