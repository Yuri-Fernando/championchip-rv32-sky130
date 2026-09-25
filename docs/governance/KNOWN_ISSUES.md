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
| KI-07 | Arquivos intermediários do run baseline do OpenLane (logs por etapa, DEFs, relatórios de timing) foram apagados por engano em 25/09/2026 (ver `versioning/HISTORICO.md`) | Baixa (evidências finais preservadas) | GDSII, netlist, `metrics.json`, config e imagem do layout intactos em `docs/evidence/openlane/run_best/`. Reproduzível com `bash scripts/run_openlane.sh`. |
| KI-08 | O gerador aleatório não produz JALR, FENCE nem ECALL | Informativo | Essas três instruções têm testes dirigidos dedicados (`tb_isa_branch_jump`, `tb_isa_mem_upper_sys`). |
| KI-09 (RESOLVIDO) | Gerador aleatório não exercitava o bit 11 do imediato de branch nem o sign-extend de LB/LH | Média (lacuna de verificação) | Encontrado pelo teste de mutação; corrigido com laços (branch para trás) e janela de dados pré-preenchida. Ver ADR-014. |
| KI-10 | Violações de max slew / max cap nos corners lentos (`ss`, 100 °C, 1,60 V): ~7,5 mil / ~140 em ambas as rodadas | Média (elétrica, não funcional) | Timing de setup/hold fecha em todos os corners e DRC/LVS estão limpos. `RUN_POST_GRT_DESIGN_REPAIR` não reduziu as violações (rodada opt30). Próximo passo: reparo com corners `ss` explícitos e/ou `DESIGN_REPAIR_MAX_SLEW_PCT`/buffering de redes de alto fanout. |
