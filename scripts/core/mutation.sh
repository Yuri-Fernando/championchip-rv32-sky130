#!/usr/bin/env bash
# core/mutation.sh - Teste de mutacao da verificacao randomizada. Roda DENTRO do ambiente.
set -uo pipefail
[ -f build/random/prog_1.hex ] || python3 tools/iss/gen_random_program.py --outdir build/random > /dev/null
python3 tools/mutation/run_mutation.py "$@"
