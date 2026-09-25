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
- F8/F9: otimização física (sweep) e gate-level regression.
- F10: relatório final, vídeo, pacote de submissão.

## [v0.7-openlane-baseline]

### Adicionado
- F7 — **OpenLane baseline COMPLETO com sucesso**, alvo `rv32_core`, PDK
  `sky130A` / `sky130_fd_sc_hd`, clock 40 ns (25 MHz).
  - **DRC: 0 erros** (KLayout e Magic).
  - **LVS: 0 erros/diferenças** (device, net, pin, property — todos zero).
  - **Timing fechado em TODOS os 10 corners**: WNS = TNS = 0 (setup e hold).
  - Área do core: 653 656 µm² · área die: 681 917 µm² (≈0,68 mm², 820×831 µm).
  - Roteamento convergiu em 6 iterações (12 220 → 0 erros de DRC de rota).
  - Antenna: 2 nets/pins com violação residual (pendente de repair fino).
  - Max slew/max cap: violações presentes nos corners de processo lento
    (SS 100C 1.60V) — esperado numa rodada baseline sem otimização de
    buffer insertion; alvo de F8.
  - Artefatos: `rv32_core.gds` (GDSII), `rv32_core.nl.v` (netlist
    gate-level), `metrics.json`, imagem do layout renderizada via KLayout —
    todos em `docs/evidence/openlane/run_best/`.
- Imagem de desenvolvimento (`championchip-dev`) passou a incluir Yosys,
  `python3-tk` e o pacote `openlane` (pip), permitindo rodar o fluxo
  RTL-to-GDSII inteiramente dentro do mesmo container usado para
  simulação/firmware (ver DECISIONS.md ADR-010/011).
- `openlane/constraints/base.sdc` corrigido (comando Tcl inválido
  `remove_from_collection`, não suportado pelo interpretador do OpenROAD).

### Corrigido (troubleshooting de ambiente, não de RTL)
- OpenLane 2 (pip) não roda no Python nativo do Windows (`signal.SIGKILL`
  ausente) — ver ADR-009.
- WSL sem `sudo`/`python3-tk` impedia rodar `openlane` nativamente ali —
  contornado rodando dentro do container `championchip-dev` com o
  `docker.sock` do host montado (Docker-in-Docker via socket) — ADR-010.
- Path mismatch em containers aninhados (`-v $PWD:$PWD` resolvido pelo
  daemon real, não pelo container que pediu o mount) — contornado usando
  o path espelhado `/mnt/c/tmp/championchip-build` em todos os níveis,
  disparado a partir do WSL — ADR-011.

## [v0.8-verificacao-avancada] — 25/09/2026

### Adicionado
- **Modelo de referência independente** (`tools/iss/rv32_iss.py`): simulador de
  instruções RV32I + Zmmul escrito a partir da especificação (ADR-013).
- **Teste diferencial randomizado** (`tools/iss/gen_random_program.py`,
  `tb/random/tb_random.sv`): 20 programas × 200 instruções idênticos ao modelo;
  comparação pela memória, válida para RTL e gate-level.
- **Teste de mutação** (`tools/mutation/run_mutation.py`): 13/13 bugs detectados
  (ADR-014). Encontrou e corrigiu duas lacunas do gerador.
- **F8 — otimização física**: rodada a 30 ns (33,3 MHz), DRC 0, LVS 0, timing
  fechado nos 9 corners (`openlane/config/config_opt30.json`); SDC passa a ler
  `CLOCK_PERIOD` da configuração.
- **F9 — simulação gate-level** (`scripts/run_gls.sh`): firmware + 10 programas
  aleatórios nas netlists baseline e otimizada, equivalentes ao modelo (ADR-015).
- **Scripts portáveis** (`scripts/_env.sh`, `scripts/core/`): Windows (espelho),
  Linux (Docker) e nativo (`CHAMPIONCHIP_NATIVE=1`).
- **CI** no GitHub Actions (`.github/workflows/ci.yml`): lint, regressão e mutação a cada push.
- Waveforms SVG (`tools/vcd2svg.py`), cobertura por instrução, relatórios
  consolidados (`tools/build_reports.py` → `reports/`).
- **Dashboard** HTML autocontido (`dashboard/index.html`).
- **Notebooks** por etapa (`notebooks/00`–`03`), gerados por `tools/make_notebooks.py`.
- **Apresentação** de 17 slides e **roteiro do vídeo** (~6:26) gerados dos números
  reais (`tools/deck/`, `docs/video/`).
- `versioning/HISTORICO.md` e `versioning/REGISTRO_MESTRE.md`.

### Alterado
- Reorganização: guia em `docs/reference/`, plano e rascunho em `docs/planning/`,
  governança em `docs/governance/`, notebooks em `notebooks/`, changelog em `versioning/`.
- `run_openlane.sh` parametrizado (config + rótulo) e sem dependência do WSL (ADR-012).
- `sync_mirror.sh` não copia mais runs do OpenLane para a pasta sincronizada.

### Incidente
- Arquivos intermediários do run baseline apagados por engano; evidências finais
  preservadas (KI-07, `versioning/HISTORICO.md`).

### Pendente
- Xicrc (SG-01), macro de memória (SG-02), pinagem (SG-03), reset (SG-04),
  firmware oficial (SG-05); slew/cap no corner lento (KI-10); gravação do vídeo.
