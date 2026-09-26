# HISTÓRICO — linha do tempo do projeto

Registro cronológico de como o projeto evoluiu, sessão a sessão: o que foi
feito, o que deu errado e como foi resolvido. Complementa o
[`CHANGELOG.md`](CHANGELOG.md) (o que mudou em cada versão) e o
[`REGISTRO_MESTRE.md`](REGISTRO_MESTRE.md) (onde está cada coisa).
Histórico completo de arquivos: `git log --stat`.

---

## Origem — 14/09/2026: do guia ao plano

- Material de partida: o guia oficial da Fase 2 (PDF de ~60 páginas) e um
  **Plano Mestre de Engenharia** de 19 páginas derivado dele
  (documento interno de planejamento), com arquitetura, FSM, matriz de 47 instruções, estratégia
  de verificação, fluxo OpenLane, riscos e protocolo de execução por fases.
- A nota inicial de planejamento já apontava os
  quatro pontos críticos: alvo RV32I + Zmmul + Xicrc = 47 instruções; manter
  multicycle; DMEM síncrona exige estado de espera; CRC sem parâmetros no guia
  (não inventar).
- A pasta do projeto não tinha repositório nem template oficial da
  competição — só os documentos.

## Sessão 1 — 14/09/2026: RTL, verificação, firmware e silício

**F0–F1.** Estrutura de repositório, 14 módulos RTL, imagem Docker de
desenvolvimento (Icarus Verilog, Verilator, GCC RISC-V, GTKWave).

**Obstáculo de ambiente #1.** O Docker Desktop não monta a unidade do Google
Drive (`G:`). Solução: espelhar as fontes em `C:/tmp/championchip-build`
(ADR-007).

**F2–F5.** 8 testbenches unitários e 4 de ISA. Todos passaram, exceto o de
branches/saltos, que revelou **dois bugs reais** (ADR-003):
1. PC atualizado duas vezes em JAL/JALR (EXEC_JUMP e WB_ALU escreviam o PC) —
   exatamente o risco R-07 que o Plano Mestre previa.
2. O endereço de retorno (PC+4) era lido do PC já saltado. Corrigido com o
   registrador `link_reg`.

Resultado: 44/47 instruções fechadas; Xicrc isolada como BLOCKED-XICRC.

**F6.** Firmware autoral em estilo `riscv-tests`, compilado com
`riscv64-unknown-elf-gcc -march=rv32im`. Primeiro build gerou um binário de
264 MB (o `objcopy` preencheu o vão entre IMEM e DMEM); corrigido extraindo só
`.text`. Resultado: PASS 9/9.

**F7 — sete tentativas até o GDSII.** Cada falha foi diagnosticada e
registrada (ADR-009 a ADR-011):
1. `pip install openlane` no Python do Windows → `signal.SIGKILL` não existe.
2. No WSL → sem `sudo` para instalar `python3-tk`.
3. Dentro do container, sem Yosys no PATH → blackbox das células quebrado.
4. Yosys do Ubuntu sem a opção `-y` → descoberto o modo `--dockerized`.
5. `--dockerized` sem TTY → `docker run -t`.
6. Caminhos em Docker-dentro-do-Docker → cadeia disparada a partir do WSL.
7. SDC com `remove_from_collection` (não existe no OpenSTA) → corrigido.

Resultado do baseline (40 ns): **DRC 0, LVS 0, timing fechado em todos os
corners**, die de 0,68 mm², folga de setup de 11,57 ns no pior corner.

**Notebook** Jupyter ponta a ponta com saídas reais embutidas.

## Sessão 2 — 16/09/2026: consolidação

- `.gitignore` para não versionar os ~2 GB do run do OpenLane nem os GDS.
- Commit do F7.

## Sessão 3 — 25/09/2026: melhorias, dashboard, apresentação e entrega

**Reorganização.** Governança em `docs/governance/`; notebooks em
`notebooks/`; histórico e changelog nesta pasta `versioning/`. Pastas vazias
receberam função (CI, waveforms, cobertura, relatórios) ou foram removidas.

**Incidente (transparência).** Ao limpar a cópia de 2,2 GB do run baseline
de dentro da pasta do Google Drive, a verificação de segurança ("a cópia
existe no espelho local?") falhou — o espelho em `C:/tmp` tinha sido limpo
entre sessões —, mas o comando de remoção estava numa linha separada e
executou mesmo assim. Perderam-se os **arquivos intermediários** do run
baseline (logs por etapa, DEFs, relatórios de timing). As **evidências
finais foram preservadas** (GDSII, netlist, `metrics.json`, config e imagem
do layout), e o run é reproduzível com `bash scripts/run_openlane.sh`.
Lição aplicada: `sync_mirror.sh` não copia mais runs do OpenLane para a pasta
sincronizada, e checagens de segurança passaram a ser encadeadas com `&&`.

**Obstáculo de ambiente #2.** Após reiniciar o Docker Desktop, a integração
com o WSL não subiu (socket só para root, sem `sudo`). Descoberta uma rota
melhor: o caminho `/run/desktop/mnt/host/c/...` funciona como bind mount em
todos os níveis de container direto do Windows, sem WSL (ADR-012).

**Modelo de referência + teste diferencial randomizado** (seção 7.4 do plano,
risco R-04). Simulador de instruções em Python escrito a partir da
especificação (`tools/iss/`) e gerador de programas aleatórios com assinatura
em memória. 20 programas × 200 instruções: idênticos ao RTL.

**Teste de mutação — a verificação verificando a si mesma.** 13 bugs
realistas injetados no RTL. Primeira medição: um `sed` que não aplicava deu
um falso "0 detectados"; refeito em Python com substituição verificada.
Resultado real 12/13, e o sobrevivente revelou uma **lacuna no gerador**:
o bit 11 do imediato de branch nunca era exercitado (só saltos curtos para
frente). Solução: laços com contagem regressiva (branch para trás). Em
seguida o `LH sem sign-extend` passou a escapar — segunda lacuna: os loads
quase sempre liam zero. Solução: preencher a janela de dados com valores
aleatórios. **Resultado final: 13/13 (100%).**

**F8 — otimização física.** Pela folga do baseline, o caminho crítico no
pior corner cabia em ~28 ns. Nova rodada a 30 ns (33,3 MHz) com reparo de
slew/capacitância depois do roteamento global (`config_opt30.json`); o SDC
passou a ler `CLOCK_PERIOD` da configuração.

**F9 — simulação gate-level.** A netlist pós-layout (células
`sky130_fd_sc_hd` com modelos funcionais) roda o firmware e 10 programas
aleatórios dentro do mesmo SoC: resultado idêntico ao modelo de referência.

**Infraestrutura.** Scripts portáveis (`scripts/_env.sh`: Windows com
espelho, Linux com Docker, ou nativo), CI no GitHub Actions, waveforms em SVG
(`tools/vcd2svg.py`), agregador de evidências (`tools/build_reports.py`),
dashboard HTML (`tools/build_dashboard.py`), notebooks por etapa
(`tools/make_notebooks.py`), apresentação e roteiro do vídeo gerados dos
números reais.

## Sessão 4 — 25/09/2026 (tarde): correções, publicação e entrega limpa

**Arquivos intermediários restaurados (KI-07).** A rodada baseline foi refeita:
resultado idêntico ao original (mesmo GDS, byte a byte do mesmo tamanho), o
que confirma que o fluxo é determinístico. Os relatórios e logs de cada etapa
passaram a ser arquivados fora da pasta temporária do sistema.

**Investigação das violações de slew/cap (ADR-016)** — hipóteses testadas
uma de cada vez:
1. Reparo pós-roteamento desligado → ligado na rodada opt30: sem efeito.
2. Reparo só no corner típico → `RSZ_CORNERS` com os 9 corners (rodada final
   v1): o log mostra o reparo carregando as bibliotecas `ss`/`ff` e corrigindo
   729 violações, mas a STA final continuou com 7.620. Resultado idêntico à opt30.
3. **Causa raiz:** a inserção heurística de diodos, ligada na configuração da sessão 1,
   roda depois do reparo e colocou 16.570 diodos (~35 % das células); a
   capacitância somada degrada o slew no corner lento. Desligada na rodada
   final v2: slew −60 %, células −35 %, folga de setup de 1,14 para 2,79 ns,
   mas surgiram 31 violações de antena (pior razão 3,16).
4. **Rodada final v3:** reparo de antena reforçado (10 iterações, margem de
   30 %, diodos só nas portas de I/O). Antena 31 → 19 (pior razão 2,87), com
   custo pequeno: folga 2,64 ns, slew 3.139. Mantida como resultado final.
   Simulação gate-level repetida na netlist final.

**Organização para publicação.** Material local (planejamento, vídeo, pacotes,
guia oficial da competição) movido para `desconsiderar/`, fora do git e do
pacote de entrega. Dashboard passou a ser saída gerada (`make dashboard`).
README reescrito no padrão do portfólio; licença MIT.

## Sessão 5 — 25–26/09/2026 (noite): SDC de sign-off

**Pedido:** corrigir o que ficou pendente (slew/cap, antena, aviso do CI).

**Diagnóstico.** Mesmo sem os diodos em massa, 3.139 pinos passavam do limite
de slew da biblioteca. Os relatórios de STA mostraram o limite de 1,5 ns (o da
biblioteca), enquanto a configuração resolvida do OpenLane tinha
`MAX_TRANSITION_CONSTRAINT = 0,75`. Motivo: essas variáveis só chegam ao
OpenROAD pelo SDC, e o `base.sdc` do projeto só criava o clock e os atrasos de
I/O. Também faltava `set_propagated_clock`: a análise pós-CTS usava clock
ideal. Os nomes de todas as variáveis testadas foram conferidos no código do
OpenLane 2.3.10 instalado antes de usar.

**Experimentos (duas rodadas em paralelo por vez, 4 CPUs):**
- A — SDC completo: 0 pinos acima de 1,5 ns; folga 1,08 ns; antena 58.
- B — A + buffer em fios longos: violou setup (−0,09 ns). Descartada.
- C — A + margem de reparo de 40 %: slew 260 (meta 0,75 ns), cap 55; folga 0,31 ns.
- D — C + diodos só em redes > 400 µm: antena 24; folga 0,09 ns. **Escolhida.**

**Limite encontrado:** no fluxo Classic, diodos e reparo de antena rodam
depois do reparo de projeto; cada diodo é carga extra na rede. Por isso antena
e cap/fanout disputam entre si. O próximo passo seria um `repair_design`
depois do reparo de antena, o que exige um fluxo customizado.

**Outros:** logs inchados por barras de progresso truncadas ("…"), corrigido no
`clean_log.py`; CI atualizado para actions v7 (Node 24).

## Sessão 6 — 26/09/2026: etapa final (SDF, varredura, publicação)

**Pedido:** rodar os próximos passos que dependem só do projeto, atualizar
README (origem, histórico, imagens clicáveis, dashboard com todos os
resultados), slides, artifact, versão, e preparar o post do LinkedIn.

**Gate-level com SDF.** Três obstáculos do Icarus 12 com os modelos temporais
da SKY130, resolvidos numa cópia dos modelos (sem tocar no PDK): sinais
`*_delayed` sem driver (o Icarus não implementa `$setuphold`), uma célula
`sdlclkp` cujo `*_delayed` vem da própria lógica (por isso a regra só vale
para entradas) e uma linha inválida na `lpflow_bleeder`. A DMEM comportamental
ganhou 3 ns de tempo de acesso no modo SDF, para não criar uma corrida que uma
SRAM real não teria.

**O erro que o método quase deixou passar.** A primeira execução passou, mas
terminou em 10.530 s de tempo simulado: o arquivo com `timescale 1ns` estava
depois do testbench na lista de compilação. O clock de "30" era de 30 s e os
atrasos do SDF não tinham efeito nenhum. Corrigido (10,53 µs, 351 ciclos) e
acrescentado o controle negativo: a 10 ns o firmware tem de falhar — e falhou.

**Resultado:** firmware + 3 programas PASS em `max_ss`, `min_ff` e `nom_tt`
(corners rodando em paralelo, ~10–15 min por simulação).

**Varredura:** 28 ns viola setup (−1,35 ns, 13 caminhos) e 45 % de utilização
também (−0,82 ns, 3 caminhos; die 22 % menor). O caminho crítico, conferido na
netlist, termina em `mult_out_reg`. Conclusão: o limite é da microarquitetura.

**Incidentes:** o Docker Desktop estava parado depois do desligamento da noite
anterior; a primeira rodada de 28 ns falhou por isso e foi relançada.
