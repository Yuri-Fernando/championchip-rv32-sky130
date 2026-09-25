#!/usr/bin/env bash
# run_gls.sh - Simulacao gate-level (F9) da netlist pos-layout do OpenLane.
# Usa o cache do PDK SKY130 do volume Docker "openlane-pdk-cache" (criado pelo
# run_openlane.sh). Uso: bash scripts/run_gls.sh [netlist.nl.v]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
NL="${1:-docs/evidence/openlane/run_best/rv32_core.nl.v}"
mkdir -p "$PROJDIR/docs/evidence/logs"
in_env "NETLIST=$NL bash scripts/core/gls.sh" -v openlane-pdk-cache:/root/.volare 2>&1 \
  | tee "$PROJDIR/docs/evidence/logs/gls_latest.log"
exit ${PIPESTATUS[0]}
