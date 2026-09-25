#!/usr/bin/env bash
# build_firmware.sh - Apenas compila o firmware (ELF, disassembly, mapa, hex).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
in_env "BUILD_ONLY=1 bash scripts/core/firmware.sh"
