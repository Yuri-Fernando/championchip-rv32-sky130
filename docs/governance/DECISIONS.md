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

## ADR-008 — Alvo do OpenLane baseline: `rv32_core` (núcleo puro), não `chip_top`

**Decisão:** a primeira rodada OpenLane (F7) sintetiza `rv32_core`
diretamente (regfile+ALU+decode+FSM+unidades, sem IMEM/DMEM anexadas), em
vez de `chip_top`/`soc_top`.
**Razão:** os modelos de IMEM/DMEM em `rtl/memory/` são comportamentais
(arrays com `$readmemh`/loop de inicialização) especificamente para
simulação — sintetizá-los literalmente geraria uma ROM/SRAM absurda em
flip-flops (até 4 MB para a IMEM), o que o próprio Plano Mestre proíbe
explicitamente (risco R-02). A estratégia de memória física real depende do
macro/template que a organização ainda não disponibilizou (SPEC_GAPS.md
SG-02). Sintetizar o núcleo isoladamente ainda produz uma métrica de
área/timing/densidade genuína e útil (é o bloco logicamente mais complexo),
sem contaminar o resultado com uma memória fisicamente irreal.
**Consequência:** criado `rtl/top/chip_top_min.sv` como variante mínima do
top físico (somente clk_i/rst_i) para quando a memória física estiver
definida; `chip_top.sv` completo (com pinos GPIO/serial reservados)
permanece como destino final pós-SG-03.

## ADR-009 — OpenLane 2 não roda no Python nativo do Windows (histórico)

Tentativa inicial: `pip install openlane` num venv Python nativo do
Windows. **Falhou**: o pacote importa `signal.SIGKILL` (POSIX-only) em
`openlane.steps.magic`, inexistente no Python do Windows.

## ADR-010 — OpenLane 2 executado dentro do container `championchip-dev`, com o docker.sock do host montado (Docker-in-Docker)

**Contexto:** após ADR-009, a alternativa óbvia era o WSL (Ubuntu), que tem
um Python Linux real. Mas o WSL desta máquina não tem `sudo` com senha
configurada, e o pacote `openlane` precisa de `tkinter` (usado
internamente para parsing Tcl), que depende de bibliotecas nativas
(`python3-tk`) só instaláveis via `apt` — ou seja, precisa de root.

**Decisão final:** instalar `python3-tk`, `docker.io` (CLI) e o pacote pip
`openlane` diretamente na imagem `championchip-dev` (`tools/docker/
Dockerfile`), já que dentro do `Dockerfile` a instalação roda como root
sem precisar de senha. Para o `openlane` conseguir orquestrar os
containers de síntese/PnR/STA que ele mesmo lança, o container
`championchip-dev` é executado com o socket do Docker do host montado
(`-v /var/run/docker.sock:/var/run/docker.sock`) — padrão
"Docker-in-Docker via socket compartilhado", sem precisar de um daemon
Docker aninhado de verdade.
**Consequência:** um único ambiente (`championchip-dev`) cobre simulação
RTL, firmware e agora também o fluxo físico, mantendo o princípio de
"tudo containerizado, nada instalado solto no host" (ver ADR-007).

## ADR-011 — Path espelhado `/mnt/c/...` disparado a partir do WSL para resolver Docker-outside-of-Docker

**Contexto:** com `--dockerized`, o `openlane` (rodando dentro do
container `championchip-dev`) lança ele mesmo containers auxiliares via
`docker.sock` compartilhado, pedindo bind mounts como `-v $PWD:$PWD`. Esse
pedido é resolvido pelo DAEMON real (a VM do Docker Desktop), não pelo
container que fez a chamada — então `$PWD` precisa ser um path que o
DAEMON reconheça, nao um path interno arbitrário do container "de fora".
**Tentativas que falharam:** montar em `/work` (o daemon não tem essa
pasta); montar em `/mnt/c/tmp/championchip-build` quando o `docker run`
externo é disparado do Windows/Git Bash (o cliente Windows não traduz
esse formato de path para o daemon).
**Solução:** disparar a cadeia INTEIRA (`docker run` do container
`championchip-dev` incluído) a partir de dentro do WSL (Ubuntu), montando
`/mnt/c/tmp/championchip-build` no MESMO path em todos os níveis. A partir
do WSL, o daemon do Docker Desktop resolve esse path corretamente (o WSL2
integra o mesmo `/mnt/c` que a VM interna do Docker Desktop usa), então
o path permanece válido mesmo quando um container aninhado pede o mesmo
mount novamente.
**Resultado:** `scripts/run_openlane.sh` chama `wsl -d Ubuntu -- bash -lc
"docker run ..."` em vez de rodar o `docker run` direto do Git Bash.

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

## ADR-012 — Bind mount via `/run/desktop/mnt/host/c` (substitui a rota pelo WSL do ADR-011)

**Contexto:** após reiniciar o Docker Desktop, a integração com a distro WSL
não recriou `/var/run/docker.sock` para o usuário (socket do proxy só para
root, sem `sudo`), quebrando a rota do ADR-011.
**Decisão:** montar o espelho usando o caminho que a própria VM do Docker
Desktop usa para o drive C: — `/run/desktop/mnt/host/c/tmp/championchip-build`
— no mesmo caminho dentro do container. Testado: funciona tanto no
`docker run` externo (disparado do Git Bash) quanto nos containers aninhados
que o OpenLane lança pelo `docker.sock`.
**Consequência:** `scripts/run_openlane.sh` não depende mais do WSL.

## ADR-013 — Modelo de referência independente + teste diferencial randomizado

**Decisão:** escrever um simulador de instruções (ISS) em Python a partir da
especificação RISC-V (`tools/iss/rv32_iss.py`), sem olhar o RTL, e comparar
RTL × ISS em programas aleatórios (`tools/iss/gen_random_program.py`,
`tb/random/tb_random.sv`).
**Razão:** mitigação do risco R-04 (signedness em MUL/SLT/branch) prevista na
seção 7.4 do Plano Mestre. Testes dirigidos só verificam os casos que quem os
escreveu imaginou; o oráculo independente cobre combinações que ninguém
imaginou.
**Detalhes de projeto:** a comparação é feita pela memória (janela de dados +
"assinatura" com o valor final de x1..x30), nunca pela hierarquia interna do
núcleo — por isso o mesmo teste roda no RTL e na netlist gate-level. Todo
salto para frente cai no início de um item e todo laço tem contador, então
todo programa termina.

## ADR-014 — Teste de mutação como métrica de qualidade da verificação

**Decisão:** `tools/mutation/run_mutation.py` injeta 13 bugs realistas (troca
signed/unsigned, sign-extend esquecido, bit de imediato, x0 gravável, link
errado...) e exige que cada um seja detectado por pelo menos um programa.
**Razão:** "todos os testes passam" não diz nada sobre a força dos testes.
**Resultado:** revelou duas lacunas no gerador (bit 11 do imediato B nunca
exercitado; loads lendo quase sempre zero), corrigidas. Score final 13/13.

## ADR-015 — Simulação gate-level com modelos funcionais das células

**Decisão:** `scripts/core/gls.sh` compila a netlist pós-layout com
`primitives.v` + `sky130_fd_sc_hd.v` (`-DFUNCTIONAL -DUNIT_DELAY=#1`) no lugar
do RTL do núcleo, dentro do mesmo `soc_top`, e roda firmware + programas
aleatórios.
**Razão:** fecha a fase F9 do Plano Mestre (risco R-09, divergência RTL × GL).
Simulação funcional (sem atrasos SDF): verifica a lógica gerada pela síntese;
o timing já é coberto pela STA multi-corner do OpenLane.

## ADR-016 — Desligar a inserção heurística de diodos (causa raiz das violações de slew/cap)

**Contexto:** as rodadas baseline e opt30 fechavam timing, mas tinham ~7,5 mil
violações de max slew e ~140 de max cap nos corners lentos (`ss`, 100 °C,
1,60 V). Duas hipóteses foram testadas e descartadas com evidência:
1. *Reparo pós-roteamento desligado* — ligado na opt30 (`RUN_POST_GRT_DESIGN_REPAIR`),
   sem efeito.
2. *Reparo atuando só no corner típico* — `RSZ_CORNERS` estava vazio (o reparo
   usava apenas `nom_tt`). Na rodada "final" v1 o reparo passou a enxergar os
   9 corners (confirmado no `resolved.json` e no log, que carregou as libs
   `ss`/`ff`): o reparo pós-posicionamento achou e corrigiu 729 violações de
   slew, o pós-roteamento não achou nenhuma — e ainda assim a STA final
   mostrou 7.620. Resultado idêntico ao da opt30.
**Causa raiz:** `RUN_HEURISTIC_DIODE_INSERTION: true` (herdado, na sessão 1, da
opção legada `DIODE_INSERTION_STRATEGY`). Essa etapa roda **depois** do reparo
de projeto e insere um diodo de antena em quase todo pino de rede longa:
**16.570 diodos, ~35 % das 46,8 mil células**. Cada diodo soma capacitância
à rede, o que degrada o slew no corner lento sem que nenhum reparo rode
depois. Metade das 7.760 linhas de violação no relatório `max_ss` são os
próprios pinos `ANTENNA_*/DIODE`.
**Decisão:** `config_final.json` desliga a inserção heurística e mantém o
reparo de antena direcionado (`RUN_ANTENNA_REPAIR`, padrão do OpenLane, com
`GRT_ANTENNA_ITERS: 5`), que só insere diodos onde há violação de antena real;
mantém também `RSZ_CORNERS` com os 9 corners e `CTS_CORNERS` com os corners
extremos.
**Resultado:**

| Rodada (30 ns) | Diodos | Células | Slew / Cap (`max_ss`) | Antena (pior razão) | Folga de setup |
|---|---|---|---|---|---|
| v1 — heurística ligada | 16.570 | 46.826 | 7.620 / 140 | 2 | 1,14 ns |
| v2 — heurística desligada, `GRT_ANTENNA_ITERS` 5 | 344 | 30.600 | 3.042 / 111 | 31 (3,16) | 2,79 ns |
| **v3 — + `GRT_ANTENNA_ITERS` 10, `GRT_ANTENNA_MARGIN` 30, `DIODE_ON_PORTS` both** | 691 | 30.947 | 3.139 / 111 | **19 (2,87)** | 2,64 ns |

A v3 foi mantida: troca 3 % de slew por 39 % menos violações de antena, que
são um risco de fabricação (dano ao óxido de porta), enquanto slew no corner
lento é um risco elétrico que não quebra a função (setup e hold fecham em
todos os corners). DRC 0 e LVS 0 nas três.
**Registro:** v1 e v3 arquivadas localmente (`final_com_diodos.tar.gz`,
`final_v3_20260925_183159.tar.gz`), v2 em `run_final_v2_sem_diodos/`; a v3 é
a `docs/evidence/openlane/run_final`.

## ADR-017 — SDC de sign-off completo e rodada final (reparo com margem + diodos só em redes longas)

**Contexto:** mesmo sem os diodos heurísticos (ADR-016), a rodada "sem_diodos"
tinha 3.139 pinos acima do limite de slew da biblioteca (1,5 ns) no corner
lento. O `base.sdc` do projeto só criava o clock e os atrasos de I/O. Sem
`set_max_transition`/`set_max_fanout`, o reparo do OpenROAD mirava o limite
da biblioteca a partir de parasitas estimados; com os parasitas máximos
extraídos depois do roteamento, o slew estourava. Faltavam também
`set_propagated_clock` (a STA pós-CTS usava clock ideal, sem skew), incerteza
de clock, derating, célula de entrada e carga de saída — tudo que o SDC padrão
do OpenLane define a partir de `MAX_TRANSITION_CONSTRAINT` (0,75 ns),
`MAX_FANOUT_CONSTRAINT` (10), `CLOCK_UNCERTAINTY_CONSTRAINT` (0,25 ns),
`TIME_DERATING_CONSTRAINT` (5 %) e `OUTPUT_CAP_LOAD` (33,4 fF).

**Decisão:** `openlane/constraints/signoff.sdc` (conteúdo do SDC padrão do
OpenLane, especializado para `clk_i`) como `PNR_SDC_FILE` e
`SIGNOFF_SDC_FILE` da rodada final. `base.sdc` fica intacto para reproduzir as
rodadas antigas (`config.json`, `config_opt30.json`, `config_sem_diodos.json`).
Quatro variantes testadas (todas a 30 ns, 9 corners, DRC 0 e LVS 0):

| Variante | Mudança sobre a anterior | Folga setup | Slew (limite 0,75 ns) | Pinos > 1,5 ns | Cap | Fanout | Antena | Células |
|---|---|---|---|---|---|---|---|---|
| sem_diodos | (ADR-016, `base.sdc`) | 2,64 ns* | — | 3.139 | 111 | — | 19 | 30.947 |
| A | `signoff.sdc` | 1,08 ns | 581 | **0** | 75 | 187 | 58 | 33.545 |
| B | A + buffer em fios > 400 µm | **−0,09 ns** ✗ | 437 | 0 | 1 | 111 | 63 | 33.920 |
| C | A + margem de reparo 40 % (slew/cap, pré e pós-GRT) | 0,31 ns | 260 | 0 | 55 | 185 | 60 | 34.123 |
| **D (final)** | C + diodos heurísticos só em redes > 400 µm | 0,09 ns | 263 | **0** | 74 | 408 | **24** | 36.784 |

\* medida com clock ideal, sem derating nem incerteza — não comparável.

**Escolha: D.** Com restrições realistas, fecha timing nos 9 corners, não tem
nenhum pino acima do limite de slew da biblioteca e tem a menor contagem de
antena entre as rodadas com o SDC completo (24, contra 58–63). B foi
descartada por violar setup.

**Limitações conhecidas (KI-10/KI-11):** 263 pinos acima da meta de 0,75 ns
(só corners `ss`; pior 1,42 ns, abaixo de 1,5 ns), 74 violações de
capacitância (excesso máximo 0,084 pF), 408 de fanout e 24 de antena (pior
razão 4,34, em met3). As de cap e fanout vêm de um limite de ordem do fluxo
Classic: a inserção de diodos e o reparo de antena rodam *depois* do reparo
de projeto e cada diodo é uma carga a mais na rede. As 50 mil linhas repetidas
nos logs vinham de barras de progresso truncadas com "…" (corrigido em
`tools/clean_log.py`).
**Registro:** A, B, C e D arquivadas em `desconsiderar/openlane_runs/`
(`signoff_*.tar.gz` e as configs); D é `docs/evidence/openlane/run_final`.
