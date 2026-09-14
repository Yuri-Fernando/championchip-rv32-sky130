# CHANGELOG.md

Convenção: cada versão registra as fases do Plano Mestre concluídas, os
testes que passam e o commit/tag correspondente.

## [v0.4-isa47] — em andamento

### Adicionado
- F0: inventário do material (PDF oficial + Plano Mestre), estrutura de
  repositório completa (`rtl/`, `tb/`, `firmware/`, `openlane/`, `docs/`,
  governança).
- F1: skeleton RTL completo (14 módulos), ambiente de simulação
  containerizado (`tools/docker/`), scripts de sync/regressão.
- F2: módulos unitários (regfile, alu, imm_gen, branch_cmp, mult_unit,
  crc_unit, lsu, address_decoder, imem, dmem) + 8 testbenches unitários,
  todos PASS.
- F3: `control_unit.sv` (decode + FSM de 16 estados) + `rv32_core.sv`
  (integração do datapath) + `soc_top.sv`/`chip_top.sv`.
- F4: fechamento RV32I 40/40 via testes dirigidos por instrução
  (`tb/isa/tb_isa_alu.sv`, `tb_isa_mem_upper_sys.sv`,
  `tb_isa_branch_jump.sv`), todos PASS.
- F5 (parcial): Zmmul 4/4 fechado (`tb_isa_zmmul.sv`, PASS). Xicrc
  bloqueado por falta de especificação oficial (SPEC_GAPS.md SG-01) —
  unidade estrutural implementada e testada estruturalmente.

### Corrigido
- Bug de PC atualizado duas vezes em JAL/JALR (risco R-07 do Plano Mestre,
  ocorreu na prática e foi capturado pelo teste dirigido). Ver DECISIONS.md
  ADR-003.
- Bug de valor de link (rd=PC+4) capturado do PC já saltado em JAL/JALR.
  Ver DECISIONS.md ADR-003.

### Status da matriz de ISA
44/47 instruções fechadas (RV32I 40/40 + Zmmul 4/4). Xicrc (3/47)
BLOCKED-XICRC — ver SPEC_GAPS.md SG-01.

### Pendente
- F6: firmware oficial (indisponível neste repositório — SPEC_GAPS.md
  SG-05); firmware de smoke-test autoral em preparação.
- F7-F9: fluxo OpenLane/SKY130 (baseline, otimização, gate-level regression).
- F10: relatório final, vídeo, pacote de submissão.
