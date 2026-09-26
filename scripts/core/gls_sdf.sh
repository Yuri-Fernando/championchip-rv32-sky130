#!/usr/bin/env bash
# =============================================================================
# core/gls_sdf.sh - Gate-level com ATRASOS REAIS (SDF) nos corners extremos.
#
# Complementa core/gls.sh (modelos funcionais, atraso unitario): aqui as
# celulas sky130_fd_sc_hd usam os modelos temporais (blocos specify) e o SDF
# que o OpenLane extraiu do layout final e anotado no core, corner a corner:
#   max_ss_100C_1v60 - o mais lento (onde o setup e critico)
#   min_ff_n40C_1v95 - o mais rapido (onde o hold e critico)
#   nom_tt_025C_1v80 - tipico
# O clock da simulacao e o do projeto (30 ns). A DMEM comportamental ganha um
# tempo de acesso de 3 ns (GLS_SDF, ver rtl/memory/dmem.sv).
#
# Entradas: $NETLIST e $SDF_DIR/rv32_core__<corner>.sdf
# Roda DENTRO do ambiente, cwd = raiz do projeto.
# =============================================================================
set -uo pipefail
NETLIST="${NETLIST:-docs/evidence/openlane/run_final/rv32_core.nl.v}"
SDF_DIR="${SDF_DIR:-docs/evidence/openlane/run_final/sdf}"
CORNERS="${CORNERS:-max_ss_100C_1v60 min_ff_n40C_1v95 nom_tt_025C_1v80}"
N_SEEDS="${N_SEEDS:-3}"     # cada programa leva ~15 min com SDF; os 10 completos rodam no GLS funcional
CLK_HALF="${CLK_HALF:-15}"   # 30 ns, o periodo fechado no layout
B=build/gls_sdf
mkdir -p "$B" reports

M="${SKY130_HD_VERILOG:-}"
if [ -z "$M" ]; then
  for root in "${PDK_ROOT:-}" "$HOME/.volare" /root/.volare; do
    [ -n "$root" ] && [ -d "$root" ] || continue
    M=$(find "$root" -path "*sky130A/libs.ref/sky130_fd_sc_hd/verilog" -type d 2>/dev/null | head -1)
    [ -n "$M" ] && break
  done
fi
[ -f "$NETLIST" ] || { echo "ERRO: netlist nao encontrada ($NETLIST)"; exit 1; }
[ -n "$M" ] || { echo "ERRO: modelos sky130_fd_sc_hd nao encontrados (defina SKY130_HD_VERILOG)"; exit 1; }
echo "netlist: $NETLIST · clock $((CLK_HALF * 2)) ns · corners: $CORNERS"

# Copia ajustada dos modelos temporais para o Icarus 12 (o PDK nao e alterado);
# detalhes em tools/sky130_timing_models.awk.
CELLS="$B/sky130_fd_sc_hd_timing.v"
awk -f tools/sky130_timing_models.awk "$M/sky130_fd_sc_hd.v" > "$CELLS"

# sem -DFUNCTIONAL: modelos temporais com specify; -gspecify liga os atrasos
GL="-g2012 -gspecify -DGLS_SDF -DSDF_ANNOTATE -DCLK_HALF=$CLK_HALF -DUNIT_DELAY= -Irtl/core -Irtl/memory -Irtl/top -Itb/common"
# timescale_ns.vh PRIMEIRO: o `timescale vale para os arquivos seguintes, e o
# testbench precisa estar em ns (senao o clock de "30" vira 30 s e os atrasos
# do SDF somem na escala)
TS=tb/common/timescale_ns.vh
GLSRC="rtl/memory/address_decoder.sv rtl/memory/imem.sv rtl/memory/dmem.sv rtl/top/soc_top.sv $NETLIST $M/primitives.v $CELLS"
SUM=reports/gls_sdf_summary.csv
echo "corner,teste,status" > "$SUM"
FAIL=0

[ -f firmware/build/smoke_test.hex ] || BUILD_ONLY=1 bash scripts/core/firmware.sh > /dev/null
OFF=$(( (0x$(awk '/ result_addr$/ {print $1}' firmware/build/smoke_test.sym) - 0x10010000) / 4 ))
[ -f build/random/prog_1.hex ] || python3 tools/iss/gen_random_program.py --seeds $(seq 1 "$N_SEEDS") --outdir build/random > /dev/null

# compila uma vez; o SDF de cada corner entra em tempo de execucao (+SDF=)
iverilog $GL -DRESULT_WORD_OFFSET=$OFF -o "$B/fw.vvp" $TS tb/firmware/tb_firmware_smoke.sv $GLSRC > "$B/fw.clog" 2>&1 \
  || { echo "ERRO de compilacao (firmware)"; tail -20 "$B/fw.clog"; exit 1; }
iverilog $GL -o "$B/random.vvp" $TS tb/random/tb_random.sv $GLSRC > "$B/random.clog" 2>&1 \
  || { echo "ERRO de compilacao (random)"; tail -20 "$B/random.clog"; exit 1; }

# um corner por processo (os corners sao independentes); resultados em
# $B/<corner>.csv, agregados no fim na ordem de $CORNERS
run_corner() {
  local c="$1" SDF="$SDF_DIR/rv32_core__$1.sdf" out="$B/$1.csv" PASSED=0 s ST
  : > "$out"
  [ -f "$SDF" ] || { echo "ERRO: $SDF nao encontrado"; echo "$c,sdf,AUSENTE" >> "$out"; return 1; }
  vvp -n "$B/fw.vvp" "+SDF=$SDF" > "$B/fw_$c.log" 2>&1
  if grep -q "=== tb_firmware_smoke: PASS" "$B/fw_$c.log"; then echo "PASS  sdf/$c/firmware"; echo "$c,firmware,PASS" >> "$out"
  else echo "FAIL  sdf/$c/firmware"; tail -12 "$B/fw_$c.log"; echo "$c,firmware,FAIL" >> "$out"; fi
  for s in $(seq 1 "$N_SEEDS"); do
    vvp -n "$B/random.vvp" "+SDF=$SDF" "+PROG=build/random/prog_$s.hex" "+EXP=build/random/expected_$s.hex" > "$B/random_${c}_$s.log" 2>&1
    if grep -q ": PASS" "$B/random_${c}_$s.log"; then PASSED=$((PASSED + 1)); else tail -6 "$B/random_${c}_$s.log"; fi
  done
  [ "$PASSED" = "$N_SEEDS" ] && ST=PASS || ST=FAIL
  echo "$ST  sdf/$c/random ($PASSED/$N_SEEDS programas identicos ao modelo de referencia)"
  echo "$c,random ${N_SEEDS} programas,$ST" >> "$out"
}

echo "==== corners em paralelo: $CORNERS ===="
for c in $CORNERS; do run_corner "$c" & done
# Controle negativo: o mesmo firmware no corner lento com clock de 10 ns (o
# caminho critico e ~29 ns). Se os atrasos do SDF estiverem mesmo aplicados, a
# simulacao TEM de falhar; um PASS aqui significaria que o SDF nao entrou.
NEG_CORNER=max_ss_100C_1v60
run_negative() {
  iverilog ${GL/-DCLK_HALF=$CLK_HALF/-DCLK_HALF=5} -DRESULT_WORD_OFFSET=$OFF -o "$B/fw_neg.vvp" $TS tb/firmware/tb_firmware_smoke.sv $GLSRC > "$B/fw_neg.clog" 2>&1
  vvp -n "$B/fw_neg.vvp" "+SDF=$SDF_DIR/rv32_core__$NEG_CORNER.sdf" > "$B/fw_neg.log" 2>&1
  if grep -q "=== tb_firmware_smoke: PASS" "$B/fw_neg.log"; then
    echo "FALHA DO METODO  controle negativo passou: os atrasos do SDF nao estao sendo aplicados"
    echo "$NEG_CORNER,controle negativo 10 ns (deve falhar),PASSOU - SDF INEFETIVO" > "$B/negativo.csv"
  else
    echo "OK    controle negativo falhou como esperado (atrasos reais aplicados)"
    echo "$NEG_CORNER,controle negativo 10 ns (deve falhar),FALHOU COMO ESPERADO" > "$B/negativo.csv"
  fi
}
rm -f "$B/negativo.csv"
if [ -f "$SDF_DIR/rv32_core__$NEG_CORNER.sdf" ] && [ "${SKIP_NEGATIVE:-0}" != 1 ]; then
  echo "==== controle negativo: $NEG_CORNER com clock de 10 ns (deve falhar), em paralelo ===="
  run_negative &
fi
wait

for c in $CORNERS; do cat "$B/$c.csv" >> "$SUM"; done
[ -f "$B/negativo.csv" ] && cat "$B/negativo.csv" >> "$SUM"
grep -q ",FAIL$\|,AUSENTE$\|INEFETIVO" "$SUM" && FAIL=1


echo "==== GL-SDF RESULTADO: $([ $FAIL = 0 ] && echo 'NETLIST CORRETA COM ATRASOS REAIS NOS CORNERS' || echo 'DIVERGENCIA') ===="
exit $FAIL
