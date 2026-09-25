#!/usr/bin/env bash
# =============================================================================
# core/gls.sh - Gate-Level Simulation (F9): a netlist pos-layout gerada pelo
# OpenLane (rv32_core.nl.v, celulas sky130_fd_sc_hd) substitui o RTL do core
# dentro do mesmo soc_top, e roda o firmware + os programas aleatorios. Detecta
# divergencias RTL x silicio (sintese mal interpretada, latches, X, etc.).
#
# Requer os modelos Verilog da biblioteca (PDK SKY130 baixado pelo OpenLane):
#   SKY130_HD_VERILOG=<dir com primitives.v e sky130_fd_sc_hd.v>, ou
#   PDK_ROOT / ~/.volare (procurado automaticamente).
# Roda DENTRO do ambiente, cwd = raiz do projeto.
# =============================================================================
set -uo pipefail
NETLIST="${NETLIST:-docs/evidence/openlane/run_best/rv32_core.nl.v}"
N_SEEDS="${N_SEEDS:-10}"
B=build/gls
mkdir -p "$B" reports

M="${SKY130_HD_VERILOG:-}"
if [ -z "$M" ]; then
  for root in "${PDK_ROOT:-}" "$HOME/.volare" /root/.volare; do
    [ -n "$root" ] && [ -d "$root" ] || continue
    M=$(find "$root" -path "*sky130A/libs.ref/sky130_fd_sc_hd/verilog" -type d 2>/dev/null | head -1)
    [ -n "$M" ] && break
  done
fi
[ -f "$NETLIST" ] || { echo "ERRO: netlist nao encontrada ($NETLIST) - rode scripts/run_openlane.sh"; exit 1; }
[ -n "$M" ] || { echo "ERRO: modelos sky130_fd_sc_hd nao encontrados (defina SKY130_HD_VERILOG)"; exit 1; }
echo "netlist: $NETLIST ($(du -h "$NETLIST" | cut -f1))"

GL="-g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -Irtl/core -Irtl/memory -Irtl/top"
GLSRC="rtl/memory/address_decoder.sv rtl/memory/imem.sv rtl/memory/dmem.sv rtl/top/soc_top.sv $NETLIST $M/primitives.v $M/sky130_fd_sc_hd.v"
SUM=reports/gls_summary.csv
echo "teste,status" > "$SUM"
FAIL=0

echo "==== GL 1. firmware de smoke-test sobre a netlist ===="
[ -f firmware/build/smoke_test.hex ] || BUILD_ONLY=1 bash scripts/core/firmware.sh > /dev/null
OFF=$(( (0x$(awk '/ result_addr$/ {print $1}' firmware/build/smoke_test.sym) - 0x10010000) / 4 ))
iverilog $GL -DRESULT_WORD_OFFSET=$OFF -o "$B/fw_gl.vvp" tb/firmware/tb_firmware_smoke.sv $GLSRC > "$B/fw.clog" 2>&1
vvp -n "$B/fw_gl.vvp" > "$B/fw.log" 2>&1
if grep -q "=== tb_firmware_smoke: PASS" "$B/fw.log"; then echo "PASS  gl/firmware"; echo "firmware,PASS" >> "$SUM"
else echo "FAIL  gl/firmware"; tail -15 "$B/fw.log"; echo "firmware,FAIL" >> "$SUM"; FAIL=1; fi

echo "==== GL 2. diferencial randomizado sobre a netlist ($N_SEEDS programas) ===="
if [ ! -f build/random/prog_1.hex ]; then
  python3 tools/iss/gen_random_program.py --seeds $(seq 1 "$N_SEEDS") --outdir build/random > /dev/null
fi
iverilog $GL -o "$B/random_gl.vvp" tb/random/tb_random.sv $GLSRC > "$B/random.clog" 2>&1
PASSED=0
for s in $(seq 1 "$N_SEEDS"); do
  vvp -n "$B/random_gl.vvp" "+PROG=build/random/prog_$s.hex" "+EXP=build/random/expected_$s.hex" > "$B/random_$s.log" 2>&1
  if grep -q ": PASS" "$B/random_$s.log"; then PASSED=$((PASSED + 1)); else FAIL=1; tail -8 "$B/random_$s.log"; fi
done
[ "$PASSED" = "$N_SEEDS" ] && ST=PASS || ST=FAIL
echo "$ST  gl/random ($PASSED/$N_SEEDS programas identicos ao modelo de referencia)"
echo "random ${N_SEEDS} programas,$ST" >> "$SUM"

echo "==== GL RESULTADO: $([ $FAIL = 0 ] && echo 'NETLIST EQUIVALENTE AO MODELO' || echo 'DIVERGENCIA') ===="
exit $FAIL
