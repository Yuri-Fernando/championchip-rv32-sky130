#!/usr/bin/env bash
# =============================================================================
# sync_mirror.sh - Espelha rtl/ tb/ firmware/ openlane/ scripts/ para um path
# local fora da pasta sincronizada (Google Drive Desktop), pois o Docker
# Desktop (backend WSL2) nao consegue montar bind mounts na unidade de rede
# virtual G:\ deste projeto. Ver regra node-env.md (mesmo principio aplicado
# a Docker em vez de npm).
#
# Uso: bash scripts/sync_mirror.sh [to|from]
#   to   (default) copia do projeto para o mirror local
#   from copia artefatos gerados (evidencias/reports/runs) de volta ao projeto
# =============================================================================
set -e
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="/c/tmp/championchip-build"
DIR="${1:-to}"

mkdir -p "$MIRROR"

if [ "$DIR" = "to" ]; then
  for d in rtl tb firmware openlane scripts tools; do
    mkdir -p "$MIRROR/$d"
    cp -r "$PROJDIR/$d/." "$MIRROR/$d/" 2>/dev/null || true
  done
  echo "Sincronizado: projeto -> $MIRROR"
elif [ "$DIR" = "from" ]; then
  mkdir -p "$PROJDIR/docs/evidence" "$PROJDIR/reports"
  [ -d "$MIRROR/docs/evidence" ] && cp -r "$MIRROR/docs/evidence/." "$PROJDIR/docs/evidence/" 2>/dev/null || true
  [ -d "$MIRROR/reports" ] && cp -r "$MIRROR/reports/." "$PROJDIR/reports/" 2>/dev/null || true
  [ -d "$MIRROR/openlane/runs" ] && { mkdir -p "$PROJDIR/openlane/runs"; cp -r "$MIRROR/openlane/runs/." "$PROJDIR/openlane/runs/" 2>/dev/null || true; }
  [ -d "$MIRROR/firmware/build" ] && cp -r "$MIRROR/firmware/build/." "$PROJDIR/firmware/build/" 2>/dev/null || true
  echo "Sincronizado: $MIRROR -> projeto (evidencias/artefatos)"
else
  echo "Uso: $0 [to|from]"; exit 1
fi
