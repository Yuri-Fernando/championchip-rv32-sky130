#!/usr/bin/env bash
# =============================================================================
# run_lint.sh - Lint sintetizavel via Verilator --lint-only sobre chip_top
# (top fisico). Complementa a regressao funcional do Icarus (ver KI-06 em
# KNOWN_ISSUES.md) com uma segunda ferramenta de fato usada pelo fluxo de
# sintese (Yosys/OpenLane tem ascendencia comum de parsing com Verilator).
# =============================================================================
set -uo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$PROJDIR/scripts/sync_mirror.sh" to

export MSYS_NO_PATHCONV=1
docker run --rm -v "C:/tmp/championchip-build:/work" -w /work championchip-dev:latest bash -c '
verilator --lint-only -Wall -Irtl/core -Irtl/memory -Irtl/top --top-module chip_top \
  rtl/core/*.sv rtl/memory/*.sv rtl/top/*.sv 2>&1 | tee /tmp/lint.log
echo "---"
grep -c "%Warning" /tmp/lint.log || true
grep -c "%Error" /tmp/lint.log && exit 1 || exit 0
'
