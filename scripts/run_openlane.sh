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
# Path trap (ver DECISIONS.md ADR-010/011): quando o container aninhado
# (lancado pelo openlane) pede um bind mount "-v $PWD:$PWD", esse path e
# resolvido pelo DAEMON Docker real (a VM do Docker Desktop), nao pelo
# container que fez o pedido. Por isso TODO o comando (client docker
# incluido) precisa rodar a partir de DENTRO do WSL (Ubuntu), usando o
# path espelhado /mnt/c/tmp/championchip-build em TODOS os niveis - e' o
# unico cliente Docker que testamos onde o daemon resolve esse path
# corretamente em toda a cadeia de containers aninhados.
# =============================================================================
set -uo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR_MOUNT="/mnt/c/tmp/championchip-build"

bash "$PROJDIR/scripts/sync_mirror.sh" to

mkdir -p "$PROJDIR/openlane/runs" "$PROJDIR/docs/evidence/openlane/run_best" "$PROJDIR/docs/evidence/logs"

TAG="baseline_$(date +%Y%m%d_%H%M%S)"

wsl -d Ubuntu --cd '~' -- bash -lc "
docker volume create openlane-pdk-cache >/dev/null
docker run --rm -t \
  -v '${MIRROR_MOUNT}:${MIRROR_MOUNT}' \
  -v 'openlane-pdk-cache:/root/.volare' \
  -v '/var/run/docker.sock:/var/run/docker.sock' \
  -w '${MIRROR_MOUNT}' \
  championchip-dev:latest \
  bash -c \"openlane --dockerized --run-tag '$TAG' openlane/config/config.json\"
" 2>&1 | tee "$PROJDIR/docs/evidence/logs/openlane_baseline.log"

RC=${PIPESTATUS[0]}

LATEST_RUN="/c/tmp/championchip-build/openlane/config/runs/$TAG"
echo "Run: $LATEST_RUN"
if [ -d "$LATEST_RUN" ]; then
  mkdir -p "$PROJDIR/openlane/runs/$TAG"
  cp -r "$LATEST_RUN"/* "$PROJDIR/openlane/runs/$TAG/" 2>/dev/null || true
  find "$LATEST_RUN" -iname "metrics.json" -exec cp {} "$PROJDIR/docs/evidence/openlane/run_best/metrics.json" \; 2>/dev/null
  find "$LATEST_RUN" -iname "*.gds" -exec cp {} "$PROJDIR/docs/evidence/openlane/run_best/" \; 2>/dev/null
  find "$LATEST_RUN" \( -iname "*.gl.v" -o -iname "*.nl.v" \) -exec cp {} "$PROJDIR/docs/evidence/openlane/run_best/" \; 2>/dev/null
  cp "$PROJDIR/openlane/config/config.json" "$PROJDIR/docs/evidence/openlane/run_best/config.json" 2>/dev/null || true
  echo "Evidencias copiadas para docs/evidence/openlane/run_best/ e openlane/runs/$TAG/"
fi

exit $RC
