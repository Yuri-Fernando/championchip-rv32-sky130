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
