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

## [v0.5-firmware-smoke]

### Adicionado
- F6 (parcial — firmware oficial indisponível, ver SG-05): firmware de
  smoke-test autoral (`firmware/smoke/smoke_test.S`), compilado com
  `riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32` (sem compressed),
  linkado contra `firmware/linker/link.ld` (mapa de memória real do core),
  convertido para hex e simulado sobre `soc_top` via
  `tb/firmware/tb_firmware_smoke.sv`.
- **Resultado: PASS (9/9 blocos)** — cadeia toolchain → ELF → hex →
  simulação → execução end-to-end comprovada com ferramentas reais (não
  apenas testes dirigidos hand-encoded). Cobre ADD/SUB, lógica, shifts,
  SLT/SLTU, LUI/AUIPC, load/store (word/byte/half, sign/zero-extend),
  branch, JAL/JALR e MUL/MULH (Zmmul).
- `scripts/build_firmware.sh` e `scripts/run_firmware_sim.sh`.

### Pendente
- F6 completo: depende do firmware oficial da competição (SG-05).
- F7-F9: fluxo OpenLane/SKY130 (baseline, otimização, gate-level regression).
- F10: relatório final, vídeo, pacote de submissão.
