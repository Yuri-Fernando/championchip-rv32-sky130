#!/usr/bin/env bash
# run_firmware_sim.sh - Compila o firmware (GCC RISC-V) e o simula sobre o SoC,
# gerando log e waveform em docs/evidence/.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
in_env "bash scripts/core/firmware.sh"
