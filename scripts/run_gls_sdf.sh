#!/usr/bin/env bash
# run_gls_sdf.sh - Gate-level com atrasos reais (SDF) nos corners extremos.
# Uso: bash scripts/run_gls_sdf.sh [netlist.nl.v] [dir_com_os_sdf]
# Os SDFs vem do OpenLane (<run>/*-openroad-stapostpnr/<corner>/*.sdf); para a
# rodada final ficam em docs/evidence/openlane/run_final/sdf/ (fora do git).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
NL="${1:-docs/evidence/openlane/run_final/rv32_core.nl.v}"
SD="${2:-docs/evidence/openlane/run_final/sdf}"
mkdir -p "$PROJDIR/docs/evidence/logs"
in_env "NETLIST=$NL SDF_DIR=$SD N_SEEDS=${N_SEEDS:-10} CORNERS=\"${CORNERS:-max_ss_100C_1v60 min_ff_n40C_1v95 nom_tt_025C_1v80}\" bash scripts/core/gls_sdf.sh" -v openlane-pdk-cache:/root/.volare 2>&1 \
  | tee "$PROJDIR/docs/evidence/logs/gls_sdf_latest.log"
exit ${PIPESTATUS[0]}
