#!/usr/bin/env bash
# =============================================================================
# core/regression.sh - Regressao RTL completa. Roda DENTRO do ambiente
# (container championchip-dev ou nativo/CI), cwd = raiz do projeto.
#
#   1. 8 testbenches unitarios                     (tb/unit)
#   2. 4 testbenches dirigidos por instrucao       (tb/isa, 44/47 instrucoes)
#   3. firmware de smoke-test compilado (GCC real)  (tb/firmware)
#   4. teste diferencial randomizado vs modelo de referencia independente
#      (tools/iss) - N_SEEDS programas x N_INSTR instrucoes aleatorias
#
# Saidas: stdout (PASS/FAIL), reports/regression_summary.csv,
#         docs/evidence/isa/random_coverage.csv. Exit code != 0 se algo falhar.
# =============================================================================
set -uo pipefail
N_SEEDS="${N_SEEDS:-20}"
N_INSTR="${N_INSTR:-200}"
B=build/regression
mkdir -p "$B" reports docs/evidence/isa docs/evidence/logs
SUM=reports/regression_summary.csv
echo "suite,teste,status" > "$SUM"
FAIL=0
IV="iverilog -g2012 -Irtl/core -Irtl/memory -Irtl/top -Itb/common -Itb/isa"

check() {  # check <suite> <teste> <log>
  if grep -q "=== .*: PASS" "$3"; then
    echo "PASS  $1/$2"; echo "$1,$2,PASS" >> "$SUM"
  else
    echo "FAIL  $1/$2"; tail -20 "$3"; echo "$1,$2,FAIL" >> "$SUM"; FAIL=1
  fi
}

echo "==== 1. TESTES UNITARIOS ===="
for tb in tb_alu tb_regfile tb_imm_gen tb_branch_cmp tb_mult_unit tb_lsu tb_address_decoder tb_crc_unit; do
  $IV -o "$B/$tb.vvp" "tb/unit/$tb.sv" rtl/core/*.sv rtl/memory/*.sv > "$B/$tb.clog" 2>&1
  vvp -n "$B/$tb.vvp" > "$B/$tb.log" 2>&1
  check unit "$tb" "$B/$tb.log"
done

echo "==== 2. TESTES DE ISA (dirigidos por instrucao) ===="
for tb in tb_isa_alu tb_isa_mem_upper_sys tb_isa_branch_jump tb_isa_zmmul; do
  $IV -o "$B/$tb.vvp" "tb/isa/$tb.sv" rtl/core/*.sv rtl/memory/*.sv rtl/top/soc_top.sv > "$B/$tb.clog" 2>&1
  vvp -n "$B/$tb.vvp" > "$B/$tb.log" 2>&1
  check isa "$tb" "$B/$tb.log"
done

echo "==== 3. FIRMWARE (GCC RISC-V -> ELF -> hex -> simulacao) ===="
bash scripts/core/firmware.sh > "$B/firmware.log" 2>&1
check firmware smoke_test "$B/firmware.log"

echo "==== 4. DIFERENCIAL RANDOMIZADO vs modelo de referencia ($N_SEEDS x $N_INSTR instr.) ===="
rm -rf build/random
python3 tools/iss/gen_random_program.py --seeds $(seq 1 "$N_SEEDS") --n "$N_INSTR" --outdir build/random > "$B/gen.log"
tail -1 "$B/gen.log"
cp build/random/coverage.csv docs/evidence/isa/random_coverage.csv
$IV -o "$B/tb_random.vvp" tb/random/tb_random.sv rtl/core/*.sv rtl/memory/*.sv rtl/top/soc_top.sv > "$B/tb_random.clog" 2>&1
PASSED=0
for s in $(seq 1 "$N_SEEDS"); do
  vvp -n "$B/tb_random.vvp" "+PROG=build/random/prog_$s.hex" "+EXP=build/random/expected_$s.hex" > "$B/random_$s.log" 2>&1
  if grep -q ": PASS" "$B/random_$s.log"; then PASSED=$((PASSED + 1)); else FAIL=1; tail -10 "$B/random_$s.log"; fi
done
echo "random: $PASSED/$N_SEEDS programas identicos ao modelo de referencia"
[ "$PASSED" = "$N_SEEDS" ] && ST=PASS || ST=FAIL
echo "random,${N_SEEDS} programas x ${N_INSTR} instr,$ST" >> "$SUM"
echo "$ST  random/diferencial ($PASSED/$N_SEEDS)"

echo "==== RESULTADO: $([ $FAIL = 0 ] && echo 'TUDO PASSOU' || echo 'HA FALHAS') ===="
exit $FAIL
