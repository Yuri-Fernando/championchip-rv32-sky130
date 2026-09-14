#!/usr/bin/env bash
# =============================================================================
# run_regression.sh - Compila e roda TODOS os testbenches unitarios + ISA via
# Icarus Verilog dentro do container championchip-dev. Sincroniza fontes para
# o mirror local antes (ver sync_mirror.sh) por causa da limitacao de bind
# mount do Docker Desktop na unidade de rede do Google Drive.
#
# Uso: bash scripts/run_regression.sh
# Saida: docs/evidence/logs/regression_<timestamp>.log + exit code agregado.
# =============================================================================
set -uo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIRROR="/c/tmp/championchip-build"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PROJDIR/docs/evidence/logs"
LOG="$PROJDIR/docs/evidence/logs/regression_${TS}.log"

bash "$PROJDIR/scripts/sync_mirror.sh" to | tee -a "$LOG"

export MSYS_NO_PATHCONV=1
docker run --rm -v "C:/tmp/championchip-build:/work" -w /work championchip-dev:latest bash -c '
mkdir -p /tmp/build
FAIL=0
echo "==== UNIT TESTS ===="
for tb in tb_alu tb_regfile tb_imm_gen tb_branch_cmp tb_mult_unit tb_lsu tb_address_decoder tb_crc_unit; do
  iverilog -g2012 -Irtl/core -Irtl/memory -Itb/common -o /tmp/build/$tb.vvp tb/unit/$tb.sv rtl/core/*.sv rtl/memory/*.sv > /tmp/build/$tb.log 2>&1
  vvp /tmp/build/$tb.vvp > /tmp/build/$tb.run.log 2>&1
  if grep -q "=== .*: PASS" /tmp/build/$tb.run.log; then echo "PASS  $tb"; else echo "FAIL  $tb"; FAIL=1; tail -30 /tmp/build/$tb.run.log; fi
done
echo "==== ISA TESTS ===="
for tb in tb_isa_alu tb_isa_mem_upper_sys tb_isa_branch_jump tb_isa_zmmul; do
  iverilog -g2012 -Irtl/core -Irtl/memory -Irtl/top -Itb/common -Itb/isa -o /tmp/build/$tb.vvp tb/isa/$tb.sv rtl/core/*.sv rtl/memory/*.sv rtl/top/soc_top.sv > /tmp/build/$tb.log 2>&1
  vvp /tmp/build/$tb.vvp > /tmp/build/$tb.run.log 2>&1
  if grep -q "=== .*: PASS" /tmp/build/$tb.run.log; then echo "PASS  $tb"; else echo "FAIL  $tb"; FAIL=1; tail -30 /tmp/build/$tb.run.log; fi
done
exit $FAIL
' | tee -a "$LOG"

RC=${PIPESTATUS[0]}
echo "REGRESSION EXIT CODE: $RC" | tee -a "$LOG"
exit $RC
