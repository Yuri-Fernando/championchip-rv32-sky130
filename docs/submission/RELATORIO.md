# ChampionCHIP eXperience — Fase 2 — Relatório Técnico

**Processador:** RV32I_Zmmul_Xicrc (núcleo multicycle)
**Documento-base:** guia oficial da Fase 2 da ChampionCHIP eXperience + Plano Mestre de Engenharia (documento interno de planejamento)

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
scoreboard. Ver [`TEST_MATRIX.csv`](../governance/TEST_MATRIX.csv) para a lista
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

**Regressão completa:** 14/14 suítes PASS — 8 unitárias, 4 de ISA, firmware
e o teste diferencial randomizado (ver `docs/evidence/logs/regression_latest.log`
e `reports/regression_summary.csv`).

**Bugs reais encontrados e corrigidos pela verificação dirigida** (ver
`docs/governance/DECISIONS.md` ADR-003):
1. PC atualizado duas vezes em JAL/JALR (risco R-07 do Plano Mestre,
   materializado na prática).
2. Valor de link (rd = PC+4) capturado a partir do PC já saltado.

### 4.1 Teste diferencial randomizado (seção 7.4 do Plano Mestre)

Um simulador de instruções em Python (`tools/iss/rv32_iss.py`), escrito a partir
da especificação RISC-V e sem consultar o RTL, serve de oráculo independente.
O gerador (`tools/iss/gen_random_program.py`) cria programas com valores
iniciais aleatórios e extremos (0, −1, INT_MIN, INT_MAX), instruções de ALU,
Zmmul, LUI/AUIPC, loads/stores alinhados, branches e JAL para frente e laços
com branch para trás. Cada programa termina gravando x1..x30 na memória
("assinatura"); a comparação RTL × modelo é feita sobre 96 palavras da DMEM.

**Resultado:** 20 programas × 200 instruções, idênticos ao modelo, cobrindo
40 instruções distintas no corpo aleatório (`docs/evidence/isa/random_coverage.csv`).
JALR, FENCE e ECALL têm testes dirigidos próprios.

### 4.2 Teste de mutação

`tools/mutation/run_mutation.py` injeta, um de cada vez, 13 bugs realistas no
RTL (SRA→SRL, SLT→SLTU, SUB→ADD, MULHSU/MULHU com sinal errado, LB/LH sem
sign-extend, SH na metade errada, BLTU→BLT, BGE→BGT, bit 11 do imediato B,
x0 gravável, link do JAL sem +4) e verifica se algum programa aleatório
diverge do modelo.

**Resultado final: 13/13 mutantes detectados.** A primeira medição deu 12/13
e revelou duas lacunas no próprio gerador, ambas corrigidas: (a) só havia
saltos curtos para frente, então o bit 11 do imediato de branch nunca era
exercitado; (b) a memória começava zerada e quase todo load lia zero, então o
sign-extend de LB/LH não era testado (ADR-014).

### 4.3 Simulação gate-level (F9)

A netlist pós-layout do OpenLane (`rv32_core.nl.v`, células `sky130_fd_sc_hd`
com modelos funcionais) substitui o RTL do núcleo dentro do mesmo SoC. O
firmware e 10 programas aleatórios produzem resultado idêntico ao modelo de
referência, **nas duas netlists** (baseline e otimizada) — ver
`docs/evidence/logs/gls_baseline.log` e `gls_opt30.log` (ADR-015).

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

**Resultados (fluxo completo, 9 corners de processo/temperatura/tensão):**

| Métrica | Baseline — 40 ns | Otimizada — 30 ns |
|---------|------------------|-------------------|
| Frequência | 25,0 MHz | **33,3 MHz** |
| Folga de setup, pior corner (`max_ss_100C_1v60`) | 11,57 ns | 1,14 ns |
| WNS / TNS (setup e hold, todos os corners) | 0 / 0 | 0 / 0 |
| Folga de hold, pior corner | 0,282 ns | 0,283 ns |
| DRC KLayout / Magic | **0 / 0** | **0 / 0** |
| LVS | **0** | **0** |
| Antena | 2 | 2 |
| Max slew / max cap (corners lentos) | 7.486 / 143 | 7.620 / 140 |
| Área de standard cells | 259.760 µm² | 259.752 µm² |
| Área do core · do die | 653.656 µm² · 681.917 µm² (820,4 × 831,2 µm) | idem |
| Utilização | 39,7 % | 39,7 % |
| Potência total estimada | 31,9 mW | 42,6 mW |

**Rodada otimizada (F8).** A folga do baseline indicava um caminho crítico de
~28,4 ns no pior corner (Fmax estimada ≈ 35 MHz). A segunda rodada
(`openlane/config/config_opt30.json`) usa 30 ns e ativa o reparo de
slew/capacitância depois do roteamento global (`RUN_POST_GRT_DESIGN_REPAIR`,
`RUN_POST_GRT_RESIZER_TIMING`) e mais iterações de reparo de antena. O timing
fechou em todos os corners com 1,14 ns de folga. A potência cresce de forma
proporcional à frequência, como esperado para potência dinâmica.

**Pendência elétrica.** O reparo pós-roteamento não reduziu as violações de
max slew / max cap, que aparecem só nos corners lentos (`ss`, 100 °C, 1,60 V)
e não afetam o fechamento de timing nem DRC/LVS. Próximo passo: reparo com os
corners `ss` explícitos e buffering de redes de alto fanout
(`docs/governance/KNOWN_ISSUES.md`, KI-10).

Artefatos em [`docs/evidence/openlane/`](../evidence/openlane/) (`run_best/` =
baseline, `run_opt30/` = otimizada): `rv32_core.gds` (GDSII), `rv32_core.nl.v`
(netlist gate-level), `metrics.json`, `config.json` e imagem do layout.
Tabela consolidada: `reports/physical_sweep.csv`.

---

*Relatório gerado como parte do repositório de engenharia; para o histórico
completo de decisões e mudanças, ver `CHANGELOG.md` e `DECISIONS.md`.*
