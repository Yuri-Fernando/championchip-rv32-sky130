# STATUS.md

Gerado ao final da sessão de desenvolvimento, conforme item 16 do protocolo
de execução do Plano Mestre.

## Feito

- F0 — Inventário do material oficial (guia PDF + Plano Mestre de 19 p.
  gerado a partir dele) e estrutura de repositório completa.
- F1 — Skeleton RTL (14 módulos), ambiente de verificação containerizado
  (Docker: iverilog 12.0, verilator 5.020, gcc-riscv64-unknown-elf,
  gtkwave), scripts de sync/regressão/lint.
- F2 — 10 módulos unitários + 8 testbenches, **100% PASS**.
- F3 — `control_unit.sv` (decode + FSM 16 estados) + `rv32_core.sv`
  (datapath) + `soc_top.sv`/`chip_top.sv`/`chip_top_min.sv`.
- F4 — **RV32I 40/40** fechado e verificado por teste dirigido (scoreboard
  no regfile), 3 testbenches de ISA, 100% PASS.
- F5 — **Zmmul 4/4** fechado e verificado (100% PASS). **Xicrc 0/3**
  BLOCKED-XICRC (SPEC_GAPS.md SG-01) — unidade estrutural pronta.
- F6 (parcial) — firmware de smoke-test autoral, compilado com o GCC
  RISC-V real, executado com sucesso (**PASS, 9/9 blocos**) sobre o core.
  Firmware oficial da competição indisponível neste repositório (SG-05).
- Governança completa: README, CHANGELOG, DECISIONS (8 ADRs, incluindo 2
  bugs reais corrigidos), SPEC_GAPS (5 gaps documentados), KNOWN_ISSUES,
  TEST_MATRIX.csv.
- Notebook Jupyter de ponta a ponta (`docs/ChampionCHIP_EndToEnd.ipynb`),
  reexecutável, reproduzindo todo o pipeline com saídas reais.
- **F7 — OpenLane baseline COMPLETO com sucesso**: DRC 0 erros, LVS 0
  erros, timing fechado (WNS=TNS=0 em 10 corners), GDSII gerado
  (`rv32_core.gds`, die 820×831 µm ≈0,68 mm²). Ver
  `docs/evidence/openlane/run_best/` e `CHANGELOG.md` v0.7.

## Testes (evidência real, não simulada)

12/12 testbenches RTL PASS + firmware smoke-test PASS. Ver
`docs/evidence/logs/`.

## Métricas

- ISA: **44/47** instruções fechadas (RV32I 40/40 + Zmmul 4/4).
- Físico (`rv32_core`, sky130_fd_sc_hd, 25 MHz): DRC 0, LVS 0, WNS/TNS 0
  em 10 corners, die 0,68 mm². Ver CHANGELOG v0.7 para a tabela completa.

## Pendências / Blockers

1. **SG-01 (bloqueante para 47/47):** semântica matemática de Xicrc
   (polinômio/init/refin/refout/xorout) não especificada no guia oficial.
   Necessário material adicional da organização.
2. **SG-02 (bloqueante para fechamento físico completo):** macro/template
   de memória física oficial (IMEM até 4 MB / DMEM 8 kB) não disponível.
3. **SG-05 (bloqueante para R7 do guia):** firmware oficial da competição
   não está neste repositório.
4. **F8 (otimização física):** o baseline fechou timing com folga (clock
   relaxado, 40 ns); o corner de processo lento (SS 100C 1.60V) ainda tem
   violações de max slew/max cap e 2 antenna violations residuais — sweep
   de `CLOCK_PERIOD`/`FP_CORE_UTIL`/antenna-repair fica para uma próxima
   rodada (não bloqueia a submissão do baseline em si).
5. **F9 (gate-level regression):** simular `rv32_core.nl.v` (netlist
   gate-level gerada) contra os mesmos testbenches de ISA/firmware para
   detectar divergência RTL vs GL pós-síntese — ainda não executado.

## Próximo comando exato

```bash
# 1) Gate-level regression (F9) - simular a netlist pos-sintese:
#    adaptar tb/isa/*.sv e tb/firmware/tb_firmware_smoke.sv para
#    instanciar rv32_core.nl.v (docs/evidence/openlane/run_best/) com as
#    primitivas sky130_fd_sc_hd, em vez do RTL comportamental.

# 2) Sweep de otimizacao fisica (F8), reduzindo CLOCK_PERIOD/FP_CORE_UTIL
#    a partir de openlane/config/config.json (baseline atual: 40ns/35%):
bash scripts/run_openlane.sh

# 3) Reexecutar o notebook para embutir novos resultados:
python -m jupyter nbconvert --to notebook --execute --inplace \
  docs/ChampionCHIP_EndToEnd.ipynb

# 4) Quando o material oficial da competicao (repo/template/firmware/spec
#    Xicrc) chegar, comparar arquivo por arquivo com este RTL e atualizar
#    SPEC_GAPS.md / DECISIONS.md / TEST_MATRIX.csv conforme cada gap fechar.
```
