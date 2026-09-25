#!/usr/bin/env bash
# =============================================================================
# run_openlane.sh - Roda o fluxo RTL-to-GDSII (OpenLane 2, --dockerized) sobre
# rv32_core, usando openlane/config/config.json.
#
# O pacote "openlane" (pip) precisa de tkinter (import incondicional) e roda
# em --dockerized (para nao depender de yosys/openroad/magic/netgen locais
# na versao exata que o flow espera). Ele mesmo lanca containers auxiliares
# via docker.sock (Docker-in-Docker via socket compartilhado).
#
# Path trap (DECISIONS.md ADR-010/011/012): quando o container aninhado
# (lancado pelo openlane) pede um bind mount "-v $PWD:$PWD", esse path e
# resolvido pelo DAEMON Docker real (a VM do Docker Desktop), nao pelo
# container que fez o pedido. Por isso o espelho e montado em
# /run/desktop/mnt/host/c/tmp/championchip-build (o caminho que a propria VM
# usa para o drive C:) no MESMO caminho em todos os niveis.
#
# Uso: bash scripts/run_openlane.sh [config.json] [rotulo]
#   bash scripts/run_openlane.sh                                        -> baseline (run_best/)
#   bash scripts/run_openlane.sh openlane/config/config_opt30.json opt30 -> run_opt30/
# =============================================================================
set -uo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Path do drive C: como a VM do Docker Desktop o enxerga: valido tanto no
# docker run externo quanto nos containers aninhados que o openlane lanca
# via docker.sock (ver DECISIONS.md ADR-012; substitui a rota via WSL).
MIRROR_MOUNT="/run/desktop/mnt/host/c/tmp/championchip-build"

bash "$PROJDIR/scripts/sync_mirror.sh" to

# Uso: bash scripts/run_openlane.sh [config.json] [label]
#   default: openlane/config/config.json, label "baseline" -> run_best/
CONFIG="${1:-openlane/config/config.json}"
LABEL="${2:-baseline}"
if [ "$LABEL" = "baseline" ]; then EVID="$PROJDIR/docs/evidence/openlane/run_best"
else EVID="$PROJDIR/docs/evidence/openlane/run_${LABEL}"; fi

mkdir -p "$EVID" "$PROJDIR/docs/evidence/logs"

TAG="${LABEL}_$(date +%Y%m%d_%H%M%S)"
CONFIG_DIR="$(dirname "$CONFIG")"

export MSYS_NO_PATHCONV=1
docker volume create openlane-pdk-cache >/dev/null
docker run --rm -t \
  -v "${MIRROR_MOUNT}:${MIRROR_MOUNT}" \
  -v "openlane-pdk-cache:/root/.volare" \
  -v "/var/run/docker.sock:/var/run/docker.sock" \
  -w "${MIRROR_MOUNT}" \
  championchip-dev:latest \
  bash -c "openlane --dockerized --run-tag '$TAG' '$CONFIG'" \
  2>&1 | tee "$PROJDIR/docs/evidence/logs/openlane_${LABEL}.log"

RC=${PIPESTATUS[0]}
# log legivel: remove codigos ANSI e barras de progresso (~12 MB -> KB)
(python "$PROJDIR/tools/clean_log.py" "$PROJDIR/docs/evidence/logs/openlane_${LABEL}.log" || python3 "$PROJDIR/tools/clean_log.py" "$PROJDIR/docs/evidence/logs/openlane_${LABEL}.log") >/dev/null 2>&1

# O run completo (~2 GB) fica SOMENTE no mirror local (C:/tmp), nunca na
# pasta sincronizada do Google Drive; copiamos apenas as evidencias finais.
LATEST_RUN="/c/tmp/championchip-build/${CONFIG_DIR}/runs/$TAG"
echo "Run: $LATEST_RUN"
if [ -d "$LATEST_RUN/final" ]; then
  cp "$LATEST_RUN/final/metrics.json" "$EVID/metrics.json" 2>/dev/null
  cp "$LATEST_RUN/final/gds/"*.gds "$EVID/" 2>/dev/null
  cp "$LATEST_RUN/final/nl/"*.nl.v "$EVID/" 2>/dev/null
  cp "$PROJDIR/$CONFIG" "$EVID/config.json" 2>/dev/null || true
  echo "Evidencias copiadas para $EVID"
fi

exit $RC
