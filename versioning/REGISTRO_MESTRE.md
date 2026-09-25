# REGISTRO MESTRE — ChampionCHIP Fase 2 · RV32I_Zmmul_Xicrc

Documento único de referência do projeto: o que foi pedido, o que foi entregue,
onde está a prova de cada item e o que ainda depende de material externo.
Números atualizados em 25/09/2026 a partir de [`reports/summary.json`](../reports/summary.json)
(regenerar com `python tools/build_reports.py`).

**Mapa rápido:** [changelog](CHANGELOG.md) (o que mudou por versão) ·
[histórico](HISTORICO.md) (como e por quê, sessão a sessão) ·
[decisões](../docs/governance/DECISIONS.md) (ADR-001 a ADR-015) ·
[lacunas](../docs/governance/SPEC_GAPS.md) · [problemas conhecidos](../docs/governance/KNOWN_ISSUES.md) ·
[status](../docs/governance/STATUS.md) · [dashboard](../dashboard/index.html)

---

## 1. Identidade

| | |
|---|---|
| Competição | ChampionCHIP eXperience — Fase 2 |
| Processador | RV32I + Zmmul + Xicrc, 32 bits, núcleo multicycle (FSM de 16 estados) |
| Processo / biblioteca | SkyWater SKY130 (`sky130A`) · `sky130_fd_sc_hd` |
| Fluxo físico | OpenLane 2.3.10 (`--dockerized`), fluxo Classic |
| Mapa de memória | IMEM `0x0040_0000` (ROM, até 4 MB) · DMEM `0x1001_0000` (SRAM síncrona, 8 kB) |
| Documentos de origem | [guia oficial](../docs/reference/Champion-chip-guia-fase-2.pdf) · [Plano Mestre](../docs/planning/Plano_Mestre_ChampionCHIP_Fase2.pdf) · [nota inicial](../docs/planning/rascunho_ideia_inicial.md) |

## 2. Rastreabilidade: requisitos do guia → evidência

Requisitos R1–R10 conforme extraídos na seção 2 do Plano Mestre.

| ID | Requisito | Status | Evidência |
|---|---|---|---|
| R1 | 47 instruções (40 RV32I + 4 Zmmul + 3 Xicrc) | 🟡 44/47 | [`TEST_MATRIX.csv`](../docs/governance/TEST_MATRIX.csv); Xicrc bloqueada por SG-01 |
| R2 | Core 32 bits multicycle, FSM, datapath modular | ✅ | [`rtl/core/`](../rtl/core/), [arquitetura](../docs/architecture/overview.md) |
| R3 | IMEM até 4 MB em 0x0040_0000; DMEM 8 kB em 0x1001_0000 | ✅ funcional / 🟡 físico | [`rtl/memory/`](../rtl/memory/); macro física: SG-02 |
| R4 | LSU byte/half/word, sign/zero-extend, byte-write | ✅ | `tb_lsu`, `tb_isa_mem_upper_sys`, mutantes de LSU mortos |
| R5 | Relatório com os tópicos 1 a 6 | ✅ | [`RELATORIO.md`](../docs/submission/RELATORIO.md) |
| R6 | Área, densidade, GDSII, netlist GL, config | ✅ | [`docs/evidence/openlane/`](../docs/evidence/openlane/), [`physical_sweep.csv`](../reports/physical_sweep.csv) |
| R7 | Waveform e logs até o fim do firmware oficial | 🟡 | firmware autoral: [log](../docs/evidence/logs/firmware_smoke.log), [waveforms](../docs/evidence/waveforms/); oficial: SG-05 |
| R8 | Vídeo de 5 a 7 min | 🟡 material pronto | [apresentação](../docs/video/Apresentacao_ChampionCHIP.pptx), [roteiro](../docs/video/ROTEIRO_VIDEO.md) (~6:26); gravação: autor |
| R9 | Explicação e testbench individual por módulo | ✅ | [`tb/unit/`](../tb/unit/), seção 4 do relatório |
| R10 | 12 pinos (8 GPIO, 2 serial, clock, reset) | 🟡 | pinos reservados em `chip_top.sv`; comportamento: SG-03 |

## 3. Fases do Plano Mestre

| Fase | Entrega | Status | Evidência |
|---|---|---|---|
| F0 | Freeze de especificação | ✅ | `SPEC_GAPS.md` (SG-01 a SG-05) |
| F1 | Skeleton e automação | ✅ | `rtl/`, `tools/docker/`, `scripts/`, CI |
| F2 | Módulos unitários | ✅ | 8/8 testbenches |
| F3 | FSM + core | ✅ | `control_unit.sv`, `rv32_core.sv` |
| F4 | RV32I 40/40 | ✅ | `tb/isa/` |
| F5 | Zmmul 4/4 + Xicrc | 🟡 | Zmmul fechada; Xicrc estrutural |
| F6 | Firmware | 🟡 | autoral PASS (RTL e gate-level) |
| F7 | OpenLane baseline | ✅ | `run_best/`: 40 ns, DRC 0, LVS 0, folga 11,57 ns |
| F8 | Otimização física | ✅ | `run_opt30/`: 30 ns (33,3 MHz), DRC 0, LVS 0, folga 1,14 ns |
| F9 | Gate-level regression | ✅ | `gls_baseline.log`, `gls_opt30.log`: firmware + 10 programas aleatórios |
| F10 | Relatório, vídeo, submissão | 🟡 | tudo pronto exceto a gravação do vídeo |

## 4. Definition of Done (seção 14 do Plano Mestre)

| Gate | Critério | Status |
|---|---|---|
| Especificação | top/pinos/reset/CRC/memória confirmados ou gaps aceitos | 🟡 gaps documentados, aguardando organização |
| RTL | sem latch acidental, sintetizável | ✅ lint Verilator sem erros; síntese Yosys limpa |
| ISA | 47/47 com testes reproduzíveis | 🟡 44/47 |
| Datapath | diagrama corresponde ao RTL | ✅ |
| Módulos | todos com testbench e evidência | ✅ |
| Firmware | oficial chega ao fim | 🟡 autoral chega ao fim; oficial indisponível |
| Waveform | capturas legíveis | ✅ SVG/PNG |
| OpenLane | run reproduzível, GDSII, GL, config | ✅ duas rodadas |
| Métricas | área, densidade, timing, DRC, LVS | ✅ |
| Relatório | ≤ 20 páginas, tópicos 1–6 | ✅ |
| Vídeo | 5–7 min | 🟡 roteiro e slides prontos |
| Pacote | lista final, nada faltando | ✅ pacote compactado |

## 5. Resultados-chave

| Métrica | Baseline (40 ns) | Otimizada (30 ns) |
|---|---|---|
| Frequência | 25,0 MHz | **33,3 MHz** |
| Folga de setup, pior corner (`max_ss_100C_1v60`) | 11,57 ns | 1,14 ns |
| Fmax estimada no pior corner | 35,2 MHz | 34,7 MHz |
| Folga de hold, pior corner | 0,282 ns | 0,283 ns |
| DRC (KLayout / Magic) · LVS | 0 / 0 · 0 | 0 / 0 · 0 |
| Violações de antena | 2 | 2 |
| Max slew / max cap (corners lentos) | 7.486 / 143 | 7.620 / 140 |
| Área de standard cells · die | 259.760 µm² · 681.917 µm² | 259.752 µm² · 681.917 µm² |
| Potência total estimada | 31,9 mW | 42,6 mW |

| Verificação | Resultado |
|---|---|
| Suítes de regressão | 14/14 PASS |
| Diferencial randomizado | 20 programas × 200 instruções, idênticos ao modelo |
| Teste de mutação | 13/13 bugs detectados |
| Gate-level | firmware + 10 programas, nas duas netlists |
| Bugs reais encontrados no RTL | 2 (JAL/JALR, ADR-003) |
| Lacunas encontradas na própria verificação | 2 (gerador aleatório, ADR-014) |

## 6. Mapa de artefatos

| O quê | Onde | Gerado por |
|---|---|---|
| RTL | `rtl/core`, `rtl/memory`, `rtl/top` | autoral |
| Testbenches | `tb/unit`, `tb/isa`, `tb/firmware`, `tb/random` | autoral |
| Modelo de referência | `tools/iss/rv32_iss.py` | autoral |
| Logs de regressão | `docs/evidence/logs/*_latest.log` | `scripts/run_*.sh` |
| Cobertura aleatória | `docs/evidence/isa/random_coverage.csv` | `scripts/core/regression.sh` |
| Waveforms | `docs/evidence/waveforms/*.vcd, *.svg` | `scripts/core/firmware.sh`, `tools/vcd2svg.py` |
| Métricas físicas | `docs/evidence/openlane/run_*/metrics.json` | `scripts/run_openlane.sh` |
| GDSII / netlist | `docs/evidence/openlane/run_*/*.gds, *.nl.v` (fora do git) | `scripts/run_openlane.sh` |
| Resumos | `reports/` | `tools/build_reports.py`, `tools/mutation/run_mutation.py` |
| Dashboard | `dashboard/index.html` | `tools/build_dashboard.py` |
| Notebooks | `notebooks/0*.ipynb` | `tools/make_notebooks.py` |
| Apresentação + roteiro | `docs/video/` | `tools/deck/build_deck.js` |

## 7. Versões

| Versão | Data | Marco |
|---|---|---|
| v0.4-isa47 | 14/09/2026 | RTL completo, 44/47, dois bugs de PC corrigidos |
| v0.5-firmware-smoke | 14/09/2026 | firmware autoral PASS |
| v0.7-openlane-baseline | 14/09/2026 | GDSII com DRC 0 / LVS 0 |
| v0.8-verificacao-avancada | 25/09/2026 | ISS, randomizado, mutação 13/13, gate-level, 33,3 MHz, dashboard, notebooks, apresentação |

Detalhes em [`CHANGELOG.md`](CHANGELOG.md).
