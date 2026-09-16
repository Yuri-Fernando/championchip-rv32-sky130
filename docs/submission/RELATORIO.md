# ChampionCHIP eXperience — Fase 2 — Relatório Técnico

**Processador:** RV32I_Zmmul_Xicrc (núcleo multicycle)
**Documento-base:** `Plano_Mestre_ChampionCHIP_Fase2.pdf` + guia oficial `Champion-chip-guia-fase-2.pdf`

---

## 1. Visão geral

Objetivo: construir e validar um microcontrolador de 32 bits baseado em
RISC-V, compatível com RV32I, extensão Zmmul (multiplicação) e extensão
customizada Xicrc (CRC), demonstrando execução funcional de firmware.

**Arquitetura adotada:** núcleo multicycle simples, modular e explicitamente
verificável (FSM de 16 estados), conforme recomendado pelo Plano Mestre —
sem pipeline, forwarding, hazards ou cache nesta fase (ver `DECISIONS.md`
ADR-001).

**Mapa de memória:**

| Bloco | Base | Fim | Política |
|-------|------|-----|----------|
| IMEM | 0x0040_0000 | 0x007F_FFFF | ROM; leitura combinacional |
| DMEM | 0x1001_0000 | 0x1001_1FFF | SRAM síncrona; escrita/leitura em 1 ciclo |

Os modelos de IMEM/DMEM usados na verificação são comportamentais,
dimensionados por parâmetro (16 KiB / 8 KiB) — a capacidade lógica completa
(IMEM até 4 MB) descrita no guia não é sintetizada literalmente em
flip-flops; a estratégia de memória física fica subordinada ao
macro/template oficial da organização (`SPEC_GAPS.md` SG-02).

## 2. Instruções (matriz completa — 47 alvo)

**44/47 fechadas** (RV32I 40/40 + Zmmul 4/4), cada uma com teste dirigido e
scoreboard. Ver [`TEST_MATRIX.csv`](../../TEST_MATRIX.csv) para a lista
completa com testbench e evidência.

Xicrc (CRCB/CRCH/CRCW, 3 instruções) está **BLOCKED-XICRC**: o guia define
opcode/funct3/funct7 mas não fecha polinômio/init/reflexão/xorout nem a
semântica de rs1/rs2. Unidade estrutural implementada e parametrizada,
pronta para integração assim que a especificação oficial chegar
(`SPEC_GAPS.md` SG-01).

## 3. Datapath

```
Top-level (clk/rst) → RV32I_Zmmul_Xicrc Core (multicycle)
                          ↕ address, oe, we, bw, wdata / rdata
                      Address Decoder (MMIO routing)
                          ↙                    ↘
                    IMEM (ROM, até 4 MB)    DMEM (SRAM, 8 kB)
```

Dentro do core: PC/IR (registradores de estágio), banco de 32 registradores
(leitura combinacional, escrita síncrona), ALU compartilhada entre
ALU-reg/imm, cálculo de endereço (load/store), alvo de branch e AUIPC/JAL
(reuso de hardware entre ciclos — princípio P1), gerador de imediatos
I/S/B/U/J, comparador de branch (6 condições), multiplicador Zmmul (produto
de 64 bits com operandos estendidos), unidade CRC Xicrc (bloqueada), LSU.

FSM: `FETCH → DECODE → {EXEC_ALU|EXEC_BRANCH|EXEC_JUMP|MEM_ADDR|EXEC_MUL|
EXEC_CRC|SYSTEM} → [MEM_READ → MEM_WAIT] → WB_* → FETCH`. O estado
`MEM_WAIT` existe porque a DMEM é explicitamente síncrona no guia oficial —
um load real precisa acomodar a latência de memória, não apenas as quatro
fases lógicas Fetch/Decode/Execute/Write Back.

## 4. Módulos e testbenches

| Módulo | Responsabilidade | Testbench | Status |
|--------|-------------------|-----------|--------|
| `regfile.sv` | 32×32, x0 fixo em zero | `tb_regfile.sv` | PASS |
| `alu.sv` | 11 operações (ADD..PASSB) | `tb_alu.sv` | PASS |
| `imm_gen.sv` | Imediatos I/S/B/U/J | `tb_imm_gen.sv` | PASS |
| `branch_cmp.sv` | 6 condições de branch | `tb_branch_cmp.sv` | PASS |
| `mult_unit.sv` | MUL/MULH/MULHSU/MULHU | `tb_mult_unit.sv` | PASS |
| `crc_unit.sv` | CRCB/CRCH/CRCW (bloqueado) | `tb_crc_unit.sv` | PASS (estrutural) |
| `lsu.sv` | Load/store, sign/zero-extend, bw | `tb_lsu.sv` | PASS |
| `address_decoder.sv` | Roteamento IMEM/DMEM | `tb_address_decoder.sv` | PASS |
| `control_unit.sv` + `rv32_core.sv` | Decode+FSM+datapath | `tb_isa_*.sv` (4 arquivos) | PASS (44/44 instr. cobertas) |

**Regressão completa:** 12/12 testbenches PASS (ver
`docs/evidence/logs/regression_latest.log`).

**Bugs reais encontrados e corrigidos pela verificação dirigida** (não
"quase completo" — ver `DECISIONS.md` ADR-003):
1. PC atualizado duas vezes em JAL/JALR (risco R-07 do Plano Mestre,
   materializado na prática).
2. Valor de link (rd = PC+4) capturado a partir do PC já saltado.

## 5. Firmware

Firmware oficial da competição **não está disponível** neste repositório
(`SPEC_GAPS.md` SG-05). Como evidência interina da cadeia completa
toolchain → ELF → hex → simulação → execução, foi escrito e executado um
firmware de smoke-test autoral (`firmware/smoke/smoke_test.S`, estilo
`riscv-tests`), compilado com `riscv64-unknown-elf-gcc -march=rv32im
-mabi=ilp32` (sem extensão comprimida — o core não decodifica instruções de
16 bits) e linkado contra o mapa de memória real (`firmware/linker/link.ld`).

**Resultado:** PASS — 9/9 blocos de teste (ADD/SUB, lógica, shifts,
SLT/SLTU, LUI/AUIPC, load/store byte/half/word, branch, JAL/JALR,
MUL/MULH), assinatura `0x600DC0DE` gravada na DMEM, `EBREAK` executado em
`pc=0x0040018c`. Log completo: `docs/evidence/logs/firmware_smoke.log`.

## 6. OpenLane / SKY130

**Alvo do baseline:** `rv32_core` — o núcleo puro (sem IMEM/DMEM
comportamentais anexadas), por decisão documentada em `DECISIONS.md`
ADR-008: sintetizar um modelo de memória de até 4 MB em flip-flops não é
realista, e a estratégia de memória física está subordinada ao
macro/template oficial ainda não disponibilizado.

**Configuração:** `openlane/config/config.json` — `sky130_fd_sc_hd`,
clock relaxado (40 ns) e utilização de core 35% na primeira rodada,
priorizando robustez/completude do fluxo sobre recorde de área (seção 10.1
do Plano Mestre).

**Resultado (fluxo completo, `sky130A`/`sky130_fd_sc_hd`, clock 40 ns / 25 MHz):**

| Métrica | Valor |
|---------|-------|
| DRC (KLayout) | **0 erros** |
| DRC (Magic) | **0 erros** |
| LVS | **0 erros/diferenças** (device, net, pin, property) |
| Timing WNS/TNS (10 corners, setup+hold) | **0 / 0** em todos |
| Área do core | 653 656 µm² |
| Área do die | 681 917 µm² (≈0,68 mm², 820,4 × 831,2 µm) |
| Roteamento | convergiu em 6 iterações (12 220 → 0 erros de DRC de rota) |
| Antenna | 2 nets/pins com violação residual |
| Max slew/cap | violações nos corners de processo lento (SS 100C 1.60V) — alvo de otimização F8 |

Artefatos completos em [`docs/evidence/openlane/run_best/`](../evidence/openlane/run_best/):
`rv32_core.gds` (GDSII final), `rv32_core.nl.v` (netlist gate-level),
`metrics.json`, `config.json` e uma imagem renderizada do layout
(`rv32_core_layout.png`).

O clock relaxado (40 ns) fechou timing com folga em todos os corners —
próximo passo natural (F8) é o sweep de `CLOCK_PERIOD`/`FP_CORE_UTIL`
descrito na seção 10.2 do Plano Mestre, buscando a fronteira de frequência
sem introduzir congestionamento, e endereçar os slew/cap violations do
corner mais pessimista.

---

*Relatório gerado como parte do repositório de engenharia; para o histórico
completo de decisões e mudanças, ver `CHANGELOG.md` e `DECISIONS.md`.*
