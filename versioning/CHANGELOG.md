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

## [v0.9-final-fisico] — 25/09/2026

### Corrigido
- Violações de max slew / max cap no corner lento: causa raiz encontrada na
  inserção heurística de diodos (16.570 diodos após o reparo). Desligada, com
  reparo de antena direcionado reforçado (`config_final.json`, ADR-016):
  slew 7.620 → 3.139, células 46.826 → 30.947, área std-cell −15 %, folga de
  setup 1,14 → 2,64 ns (Fmax estimada 36,6 MHz). DRC 0, LVS 0.
- Arquivos intermediários do baseline restaurados (rodada refeita, resultado
  idêntico; KI-07 resolvido).

### Adicionado
- Rodada `run_final/` com layout renderizado e simulação gate-level
  (`gls_final.log`: firmware + 10 programas aleatórios, PASS).
- README no padrão do portfólio, licença MIT, `config_final.json`.
- KI-11: 19 violações de antena restantes (efeito colateral documentado).

### Alterado
- Material local (planejamento, guia oficial, vídeo, pacotes de entrega,
  rodadas arquivadas) movido para `desconsiderar/`, fora do git e do pacote.
- Dashboard vira saída gerada (`make dashboard`), fora do git.

### Pendente
- Xicrc (SG-01), macro de memória (SG-02), pinagem (SG-03), reset (SG-04),
  firmware oficial (SG-05); slew/cap residual (KI-10) e antena (KI-11);
  gravação do vídeo.

## [v1.0-signoff] — 26/09/2026

### Corrigido
- SDC incompleto (segunda causa das violações de slew): novo
  `openlane/constraints/signoff.sdc` com as restrições completas do SDC padrão
  do OpenLane (meta de transição 0,75 ns, fanout 10, clock propagado,
  incerteza 0,25 ns, derating 5 %, célula de entrada e carga de saída).
  Rodada final: **nenhum pino acima do limite de slew da biblioteca**
  (eram 3.139), timing fechado nos 9 corners com restrições realistas
  (folga 0,09 ns), DRC 0, LVS 0, GLS PASS (ADR-017).
- `tools/clean_log.py`: barras de progresso truncadas com "…" viravam dezenas
  de milhares de linhas repetidas nos logs.
- CI: `actions/checkout@v7` e `actions/upload-artifact@v7` (Node 24; o Node 20
  foi descontinuado nos runners do GitHub).

### Alterado
- Rodada da ADR-016 renomeada para `run_sem_diodos` (`config_sem_diodos.json`);
  `run_final` e `config_final.json` passam a ser a rodada com SDC de sign-off.
- Relatórios, dashboard e slides mostram o SDC e o limite de slew de cada
  rodada, porque as folgas das rodadas com `base.sdc` são otimistas.

### Pendente
- Cap (74), fanout (408), 263 pinos acima da meta de 0,75 ns e 24 violações de
  antena na rodada final (KI-10, KI-11); Xicrc (SG-01), macro de memória
  (SG-02), pinagem (SG-03), reset (SG-04), firmware oficial (SG-05); vídeo.
