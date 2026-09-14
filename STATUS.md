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
- Configuração OpenLane preparada (`openlane/config/config.json`,
  constraints SDC) visando `rv32_core` como alvo do baseline (ADR-008).

## Testes (evidência real, não simulada)

12/12 testbenches RTL PASS + firmware smoke-test PASS. Ver
`docs/evidence/logs/`.

## Métricas

- ISA: **44/47** instruções fechadas (RV32I 40/40 + Zmmul 4/4).
- Área/densidade/timing físicos: pendentes (ver seção OpenLane abaixo).

## Pendências / Blockers

1. **SG-01 (bloqueante para 47/47):** semântica matemática de Xicrc
   (polinômio/init/refin/refout/xorout) não especificada no guia oficial.
   Necessário material adicional da organização.
2. **SG-02 (bloqueante para fechamento físico completo):** macro/template
   de memória física oficial (IMEM até 4 MB / DMEM 8 kB) não disponível.
3. **SG-05 (bloqueante para R7 do guia):** firmware oficial da competição
   não está neste repositório.
4. **OpenLane baseline (F7):** instalação do OpenLane 2 e/ou a rodada
   completa RTL-to-GDSII pode não ter terminado dentro desta sessão — ver
   `docs/evidence/logs/openlane_baseline.log` e a seção 7 do notebook para
   o status mais atual. Rodar `bash scripts/run_openlane.sh` para
   completar/reexecutar (primeira execução baixa o PDK SKY130 via volare,
   pode levar bastante tempo).

## Próximo comando exato

```bash
# 1) Se o OpenLane ainda nao rodou ate o fim:
bash scripts/run_openlane.sh

# 2) Depois, reexecutar o notebook para embutir os resultados fisicos:
python -m jupyter nbconvert --to notebook --execute --inplace \
  docs/ChampionCHIP_EndToEnd.ipynb

# 3) Quando o material oficial da competicao (repo/template/firmware/spec
#    Xicrc) chegar, comparar arquivo por arquivo com este RTL e atualizar
#    SPEC_GAPS.md / DECISIONS.md / TEST_MATRIX.csv conforme cada gap fechar.
```
