# DECISIONS.md — Registro de decisões de arquitetura (ADRs curtos)

## ADR-001 — Microarquitetura multicycle, sem pipeline/cache/forwarding

**Decisão:** núcleo multicycle simples (FSM de 16 estados), sem pipeline,
forwarding, hazards ou cache nesta fase.
**Razão:** o guia oficial descreve compartilhamento de recursos entre ciclos;
o Plano Mestre (P1) recomenda explicitamente esta abordagem para reduzir
área/complexidade/risco de bugs, priorizando fechamento funcional sobre IPC.
**Consequência:** CPI alto, mas RTL pequeno, verificável e sintetizável com
baixo risco de timing/congestion no OpenLane.

## ADR-002 — Registradores de estágio "free-running" (estilo ALUOut clássico)

**Decisão:** `alu_out_reg`, `mult_out_reg`, `crc_out_reg` e `link_reg`
capturam o valor combinacional corrente a cada ciclo, sem write-enable
dedicado (equivalente ao ALUOut/MDR do multicycle MIPS de Patterson&Hennessy).
**Razão:** os seletores de operando da ALU dependem apenas do opcode (exceto
o caso especial de branch), então o valor combinacional permanece válido do
estágio EXEC ao estágio WB sem risco de corrupção — simplifica o controle
(menos enables = menos superfície de bug), mantendo os "registradores de
estágio/resultado" que a especificação de `rv32_core.sv` exige.

## ADR-003 — PC write-enable centralizado + BUG corrigido (double PC update em JAL/JALR)

**Contexto:** o registro de riscos do Plano Mestre (R-07) alertava
explicitamente para "PC update duplicado". Durante a verificação ISA
(`tb/isa/tb_isa_branch_jump.sv`), esse bug de fato ocorreu e foi detectado
pelos testes dirigidos, exatamente como o processo pedia.

**Bug 1 — PC atualizado duas vezes:** JAL/JALR passam por `EXEC_JUMP`
(que grava o alvo do salto no PC) e, na sequência, por `WB_ALU` (necessário
para gravar o link em `rd`). A lista original de `pc_we_o` incluía os dois
estados, então o PC era incrementado (+4) IMEDIATAMENTE DEPOIS de já ter sido
atualizado para o alvo do salto — pulando uma instrução extra.
**Correção:** `pc_we_o` em `WB_ALU` agora é condicionado a
`!(is_jal || is_jalr)` — ver `rtl/core/control_unit.sv`.

**Bug 2 — Valor de link (rd = PC+4) capturado do PC já saltado:** mesmo após
o Bug 1 corrigido, o cálculo de `pc_plus4` em `WB_ALU` usava `pc_reg`, que a
essa altura JÁ apontava para o alvo do salto (atualizado no ciclo anterior,
em `EXEC_JUMP`). O link gravado em `rd` ficava, portanto, igual a
`alvo_do_salto + 4` em vez de `endereço_do_JAL + 4`.
**Correção:** novo registrador `link_reg`, que captura `pc_plus4` na MESMA
borda de clock em que `pc_reg` é (possivelmente) atualizado para o alvo —
ambos usam o valor pré-borda de `pc_reg` (semântica não-blocante do
Verilog), então `link_reg` preserva corretamente `PC_do_JAL + 4` mesmo depois
de `pc_reg` já ter saltado. Ver `rtl/core/rv32_core.sv`.

**Evidência:** `tb/isa/tb_isa_branch_jump.sv` (12 checagens de branch + link
e destino de JAL/JALR) — FAIL antes da correção, PASS depois. Ver
`docs/evidence/logs/`.

## ADR-004 — Xicrc: unidade estrutural parametrizada, sem oráculo

Ver SPEC_GAPS.md SG-01. Decisão de projeto: nunca travar o desenvolvimento
por uma lacuna de especificação — implementar a estrutura completa e deixar
os parâmetros matemáticos como placeholders explicitamente marcados
`BLOCKED-XICRC`, prontos para receber os valores oficiais.

## ADR-005 — IMEM/DMEM comportamentais parametrizados para simulação

Ver SPEC_GAPS.md SG-02. `soc_top.sv` (top funcional) usa modelos
comportamentais dimensionados por parâmetro; `chip_top.sv` (top físico) é o
ponto de substituição pela macro/template oficial.

## ADR-006 — Sem registradores A/B (rs1_data/rs2_data) dedicados

**Decisão:** `rv32_core.sv` lê `rs1_rdata`/`rs2_rdata` diretamente do
regfile a cada ciclo (combinacional), em vez de latchar A/B como no
multicycle MIPS clássico.
**Razão:** `ir_reg` já é o registrador de estágio que mantém
`rs1_addr`/`rs2_addr` estáveis durante toda a instrução; como a leitura do
regfile é combinacional, `rs1_rdata`/`rs2_rdata` permanecem estáveis
automaticamente. Registrar A/B adicionaria registradores sem ganho de
correção (economia de área, princípio P1).

## ADR-007 — Ambiente de verificação containerizado (Docker) + mirror local

**Decisão:** toda a toolchain de simulação (Icarus Verilog, Verilator,
GTKWave, GCC RISC-V) roda dentro da imagem `championchip-dev` (ver
`tools/docker/Dockerfile`), montada via bind mount a partir de um mirror
local em `C:/tmp/championchip-build`.
**Razão:** o projeto vive numa pasta sincronizada pelo Google Drive Desktop
(unidade de rede virtual `G:`), que o backend WSL2 do Docker Desktop não
consegue montar como bind mount. `scripts/sync_mirror.sh` espelha as fontes
antes de cada rodada (mesmo princípio da regra `node-env.md` do usuário,
aplicado a Docker em vez de npm).
