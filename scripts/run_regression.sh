#!/usr/bin/env bash
# run_regression.sh - Regressao RTL completa (unit + ISA + firmware + diferencial randomizado).
# Funciona no Windows (Docker + mirror), Linux (Docker) e CI (CHAMPIONCHIP_NATIVE=1).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
mkdir -p "$PROJDIR/docs/evidence/logs"
in_env "bash scripts/core/regression.sh $*" 2>&1 | tee "$PROJDIR/docs/evidence/logs/regression_latest.log"
exit ${PIPESTATUS[0]}
