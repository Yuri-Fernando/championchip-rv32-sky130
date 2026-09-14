#!/usr/bin/env bash
# =============================================================================
# run_openlane.sh - Roda o fluxo RTL-to-GDSII (OpenLane 2) sobre rv32_core,
# usando openlane/config/config.json. Requer:
#   - Docker Desktop rodando (o OpenLane 2 orquestra seus proprios
#     containers de sintese/PnR/STA via docker.sock)
#   - venv com o pacote `openlane` instalado (ver comentario abaixo)
#   - PDK sky130A baixado via volare na primeira execucao (automatico,
#     pode levar bastante tempo/espaco na primeira vez)
#
# Setup (uma vez):
#   python -m venv C:/tmp/openlane-venv
#   C:/tmp/openlane-venv/Scripts/python.exe -m pip install openlane
#
# Uso:
#   bash scripts/run_openlane.sh
# =============================================================================
set -uo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PY="/c/tmp/openlane-venv/Scripts/python.exe"

if [ ! -f "$VENV_PY" ]; then
  echo "ERRO: venv do OpenLane nao encontrado em $VENV_PY"
  echo "Rode primeiro: python -m venv /c/tmp/openlane-venv && /c/tmp/openlane-venv/Scripts/python.exe -m pip install openlane"
  exit 1
fi

mkdir -p "$PROJDIR/openlane/runs" "$PROJDIR/docs/evidence/openlane/run_best"

"$VENV_PY" -m openlane \
  --run-tag "baseline_$(date +%Y%m%d_%H%M%S)" \
  "$PROJDIR/openlane/config/config.json" 2>&1 | tee "$PROJDIR/docs/evidence/logs/openlane_baseline.log"

RC=${PIPESTATUS[0]}

LATEST_RUN=$(ls -td "$PROJDIR/openlane/runs"/*/ 2>/dev/null | head -1)
if [ -n "$LATEST_RUN" ]; then
  echo "Run mais recente: $LATEST_RUN"
  find "$LATEST_RUN" -iname "metrics.json" -exec cp {} "$PROJDIR/docs/evidence/openlane/run_best/metrics.json" \;
  find "$LATEST_RUN" -iname "*.gds" -exec cp {} "$PROJDIR/docs/evidence/openlane/run_best/" \;
  find "$LATEST_RUN" -iname "*.gl.v" -o -iname "*.nl.v" 2>/dev/null | head -1 | xargs -I{} cp {} "$PROJDIR/docs/evidence/openlane/run_best/chip_top.gl.v" 2>/dev/null || true
  cp "$PROJDIR/openlane/config/config.json" "$PROJDIR/docs/evidence/openlane/run_best/config.json" 2>/dev/null || true
fi

exit $RC
