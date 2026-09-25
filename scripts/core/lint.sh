#!/usr/bin/env bash
# core/lint.sh - Lint sintetizavel (Verilator -Wall) sobre o top fisico. Roda DENTRO do ambiente.
set -uo pipefail
mkdir -p docs/evidence/logs
verilator --lint-only -Wall -Irtl/core -Irtl/memory -Irtl/top --top-module chip_top \
  rtl/core/*.sv rtl/memory/*.sv rtl/top/*.sv > docs/evidence/logs/lint.log 2>&1
W=$(grep -c "%Warning" docs/evidence/logs/lint.log || true)
E=$(grep -c "%Error-" docs/evidence/logs/lint.log || true)
echo "lint: $W warnings, $E erros (detalhes em docs/evidence/logs/lint.log)"
[ "$E" = 0 ]
