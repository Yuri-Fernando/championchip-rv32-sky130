# ChampionCHIP eXperience — Fase 2 — RV32I_Zmmul_Xicrc

Microcontrolador RISC-V 32 bits (núcleo multicycle), extensões **Zmmul**
(multiplicação) e **Xicrc** (CRC custom), com verificação RTL, firmware e
fluxo RTL-to-GDSII (OpenLane/SKY130).

Documento de execução: [`Plano_Mestre_ChampionCHIP_Fase2.pdf`](Plano_Mestre_ChampionCHIP_Fase2.pdf)
(19 páginas — arquitetura, ISA, FSM, verificação, OpenLane, riscos e
protocolo de execução completos). Guia oficial da competição:
[`Champion-chip-guia-fase-2.pdf`](Champion-chip-guia-fase-2.pdf).

## Status atual

| Fase | Descrição | Status |
|------|-----------|--------|
| F0 | Freeze de especificação | ✅ |
| F1 | Skeleton + automação | ✅ |
| F2 | Módulos unitários + testes | ✅ (8/8 testbenches PASS) |
| F3 | FSM + core integrado | ✅ |
| F4 | RV32I 40/40 | ✅ |
| F5 | Zmmul 4/4 + Xicrc 3/3 | ✅ Zmmul / 🔴 Xicrc BLOCKED (SPEC_GAPS.md SG-01) |
| F6 | Firmware oficial | 🔴 indisponível (SPEC_GAPS.md SG-05); smoke-test autoral em `firmware/smoke/` PASS (9/9) |
| F7 | OpenLane baseline | ✅ DRC 0, LVS 0, WNS/TNS 0 (10 corners), GDSII gerado (0,68 mm²) |
| F8 | Otimização física | ⏳ (baseline já fecha timing; corner lento tem slew/cap a otimizar) |
| F9 | Gate-level regression | ⏳ |
| F10 | Relatório/vídeo/submissão | ⏳ |

**ISA fechada: 44/47** (RV32I 40/40 + Zmmul 4/4). Ver [`TEST_MATRIX.csv`](TEST_MATRIX.csv).

## Estrutura

```
rtl/core/     núcleo: regfile, alu, imm_gen, branch_cmp, mult_unit, crc_unit,
              lsu, control_unit (decode+FSM), rv32_core (integracao)
rtl/memory/   address_decoder, imem, dmem (modelos comportamentais)
rtl/top/      soc_top (funcional/sim), chip_top (fisico/submissao)
tb/unit/      testbenches unitarios (8)
tb/isa/       testbenches dirigidos por instrucao (4, cobrem 44/47)
firmware/     smoke-test autoral (oficial indisponivel, ver SPEC_GAPS SG-05)
openlane/     config/constraints do fluxo RTL-to-GDSII
scripts/      sync_mirror, run_regression, run_lint, build_firmware, run_openlane
docs/         arquitetura, evidencias, submissao
tools/docker/ imagem de desenvolvimento (iverilog, verilator, gcc-riscv, gtkwave)
```

## Governança (seção 8.1 do Plano Mestre)

- [CHANGELOG.md](CHANGELOG.md) — mudanças por versão
- [DECISIONS.md](DECISIONS.md) — ADRs curtos (decisões e bugs corrigidos)
- [SPEC_GAPS.md](SPEC_GAPS.md) — lacunas do guia oficial e resolução
- [KNOWN_ISSUES.md](KNOWN_ISSUES.md) — bugs/limitações conhecidos
- [TEST_MATRIX.csv](TEST_MATRIX.csv) — 47 instruções x status x evidência

## Como rodar

Ambiente: Docker (imagem local `championchip-dev`, ver `tools/docker/`).
O projeto vive numa pasta sincronizada pelo Google Drive, então os scripts
espelham as fontes para `C:/tmp/championchip-build` antes de cada rodada
(ver DECISIONS.md ADR-007) — não é preciso fazer isso manualmente.

```bash
make build-image      # construir a imagem de dev (uma vez)
make test             # regressao completa (unit + ISA), ~1 min
make lint             # lint sintetizavel (Verilator) sobre chip_top
```

## Regras de projeto (não inventar)

Este projeto segue à risca a regra P4 (spec-first) do Plano Mestre: nenhuma
ambiguidade do guia oficial é resolvida por suposição silenciosa. Toda
lacuna vira uma entrada em `SPEC_GAPS.md`, com o componente correspondente
marcado (grep-ável) como `BLOCKED-*` até a especificação oficial chegar.
