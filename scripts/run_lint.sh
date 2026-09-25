#!/usr/bin/env bash
# run_lint.sh - Lint sintetizavel com Verilator.
# Funciona no Windows (Docker + mirror), Linux (Docker) e CI (CHAMPIONCHIP_NATIVE=1).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
mkdir -p "$PROJDIR/docs/evidence/logs"
in_env "bash scripts/core/lint.sh $*" 2>&1 | tee "$PROJDIR/docs/evidence/logs/lint_latest.log"
exit ${PIPESTATUS[0]}
