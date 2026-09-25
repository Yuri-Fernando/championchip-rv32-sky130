# KNOWN_ISSUES.md

Bugs/limitações conhecidos, não escondidos (regra de governança do Plano
Mestre, seção 8.1).

| ID | Descrição | Severidade | Workaround / Plano |
|----|-----------|------------|---------------------|
| KI-01 | Xicrc (CRCB/CRCH/CRCW) sem semântica matemática oficial confirmada | Bloqueante para 47/47 | Ver SPEC_GAPS.md SG-01. ISA fecha em 44/47 sem Xicrc. |
| KI-02 | `imem.sv`/`dmem.sv` são modelos comportamentais, não a macro física oficial | Bloqueante para fechamento físico | Ver SPEC_GAPS.md SG-02. |
| KI-03 | Pinout GPIO/serial não implementado (tie-off) | Risco de escopo (R10) | Ver SPEC_GAPS.md SG-03. |
| KI-04 | Firmware oficial da competição não disponível neste repositório | Bloqueante para R7 do guia | Ver SPEC_GAPS.md SG-05. Firmware de smoke-test autoral usado como evidência interina. |
| KI-05 (RESOLVIDO) | PC atualizado duas vezes em JAL/JALR | Crítico (corrigido) | Ver DECISIONS.md ADR-003. Corrigido e coberto por regressão. |
| KI-06 | Icarus Verilog 12.0 emite `sorry: constant selects...` em vários módulos (imm_gen, mult_unit, crc_unit, lsu, control_unit) | Informativo, sem impacto funcional observado | Todos os testbenches afetados por essas linhas passam com os valores esperados exatos (ver regressão); tratado como limitação de otimização do simulador, não bug funcional. Reavaliar com Verilator antes do freeze físico. |
| KI-07 (RESOLVIDO) | Arquivos intermediários do run baseline do OpenLane apagados por engano em 25/09/2026 | Baixa | Rodada baseline refeita no mesmo dia: resultado idêntico (fluxo determinístico, mesmo GDS). Relatórios e logs de cada etapa agora são arquivados fora da pasta temporária do sistema. |
| KI-08 | O gerador aleatório não produz JALR, FENCE nem ECALL | Informativo | Essas três instruções têm testes dirigidos dedicados (`tb_isa_branch_jump`, `tb_isa_mem_upper_sys`). |
| KI-09 (RESOLVIDO) | Gerador aleatório não exercitava o bit 11 do imediato de branch nem o sign-extend de LB/LH | Média (lacuna de verificação) | Encontrado pelo teste de mutação; corrigido com laços (branch para trás) e janela de dados pré-preenchida. Ver ADR-014. |
| KI-10 | Violações de max slew / max cap no corner lento (`ss`, 100 °C, 1,60 V): 3.139 / 111 na rodada final (eram ~7,6 mil / ~140) | Média (elétrica, não funcional) | **Causa raiz encontrada e corrigida em parte (ADR-016):** a inserção heurística de diodos colocava 16.570 diodos depois do reparo. Desligada, as violações caíram 59 %. O restante está só nos corners `ss` (0 no típico) e o setup/hold fecha em todos os 9 corners. Próximo passo: `DESIGN_REPAIR_MAX_SLEW_PCT`/`MAX_TRANSITION_CONSTRAINT` mais apertados ou buffering manual das redes de alto fanout. |
| KI-11 | 19 violações de antena na rodada final (pior razão 2,87 em met3; limite 1,0) | Média (fabricação) | Efeito colateral de desligar os diodos heurísticos (ADR-016). O reparo direcionado reforçado (10 iterações, margem 30 %) reduziu de 31 para 19. Próximo passo: jumper de camada (subir o trecho longo para uma camada superior) ou diodo manual nas 19 redes listadas em `checkantennas/reports/antenna_summary.rpt`. |
