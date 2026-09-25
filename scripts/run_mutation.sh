#!/usr/bin/env bash
# run_mutation.sh - Teste de mutacao (mede a forca da verificacao).
# Funciona no Windows (Docker + mirror), Linux (Docker) e CI (CHAMPIONCHIP_NATIVE=1).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
mkdir -p "$PROJDIR/docs/evidence/logs"
in_env "bash scripts/core/mutation.sh $*" 2>&1 | tee "$PROJDIR/docs/evidence/logs/mutation_latest.log"
exit ${PIPESTATUS[0]}
