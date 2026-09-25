#!/usr/bin/env python3
"""
make_notebooks.py - Gera os notebooks Jupyter do projeto (notebooks/*.ipynb).
Os notebooks sao gerados por codigo para ficarem versionaveis e reprodutiveis;
depois de gerados, executar com:
    python -m jupyter nbconvert --to notebook --execute --inplace notebooks/0*.ipynb

  00_pipeline_completo  - roda o pipeline inteiro e mostra o resumo
  01_verificacao_rtl    - regressao, modelo de referencia, randomizado, mutacao
  02_firmware           - fonte, build, disassembly, simulacao, waveforms
  03_fisico_openlane    - config, metricas, sweep de clock, layout, gate-level
"""
from __future__ import annotations

from pathlib import Path

import nbformat as nbf

ROOT = Path(__file__).resolve().parent.parent
NB = ROOT / "notebooks"

SETUP = """import sys, json
from pathlib import Path
sys.path.insert(0, str(Path.cwd()))          # notebooks/_common.py
from _common import ROOT, run, py, summary, style, SERIES
import pandas as pd
import matplotlib.pyplot as plt
from IPython.display import SVG, Image, Markdown, display
print("projeto:", ROOT.name)"""


def build(name: str, cells: list[tuple[str, str]]) -> None:
    nb = nbf.v4.new_notebook()
    nb["metadata"]["kernelspec"] = {"name": "python3", "display_name": "Python 3", "language": "python"}
    nb["cells"] = [nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src) for kind, src in cells]
    nbf.write(nb, NB / name)
    print("gerado:", name)


# ---------------------------------------------------------------- 00
build("00_pipeline_completo.ipynb", [
    ("md", """# 00 · Pipeline completo — RV32I_Zmmul_Xicrc

Este notebook executa, na ordem, **todo** o fluxo de engenharia do processador
submetido à Fase 2 da ChampionCHIP eXperience e termina no painel de resultados:

| etapa | o que prova | script |
|---|---|---|
| 1. Lint | o RTL é sintetizável (Verilator `-Wall`) | `scripts/run_lint.sh` |
| 2. Regressão | 8 testes unitários + 4 de ISA + firmware + 20 programas aleatórios vs modelo de referência | `scripts/run_regression.sh` |
| 3. Mutação | a verificação realmente detecta bugs injetados | `scripts/run_mutation.sh` |
| 4. Gate-level | a netlist pós-layout se comporta igual ao modelo | `scripts/run_gls.sh` |
| 5. Relatórios | agrega todas as evidências | `tools/build_reports.py` |
| 6. Dashboard | painel HTML autocontido | `tools/build_dashboard.py` |

O fluxo físico (OpenLane, ~50 min por rodada) fica no notebook `03`. Os detalhes
de cada etapa estão nos notebooks `01` a `03`.

> **Pré-requisitos:** Docker em execução com a imagem `championchip-dev`
> (`make build-image`) — ou as ferramentas instaladas localmente com
> `CHAMPIONCHIP_NATIVE=1`. Ver `README.md`."""),
    ("code", SETUP),
    ("md", "## 1. Lint sintetizável"),
    ("code", 'run("bash scripts/run_lint.sh", tail=5)'),
    ("md", "## 2. Regressão completa"),
    ("code", 'run("bash scripts/run_regression.sh", tail=30)'),
    ("md", "## 3. Teste de mutação"),
    ("code", 'run("bash scripts/run_mutation.sh", tail=16)'),
    ("md", "## 4. Simulação gate-level da netlist pós-layout"),
    ("code", 'run("bash scripts/run_gls.sh", tail=10)'),
    ("md", "## 5. Resumo consolidado"),
    ("code", """S = summary()
v = S["verification"]
display(Markdown(f\"\"\"
| indicador | resultado |
|---|---|
| Instruções fechadas | **{S['isa']['closed']}/{S['isa']['total']}** (RV32I {S['isa']['rv32i']}/40 · Zmmul {S['isa']['zmmul']}/4 · Xicrc bloqueada) |
| Suítes de regressão | **{v['regression_pass']}/{len(v['regression'])}** PASS |
| Mutation score | **{v['mutation_killed']}/{len(v['mutation'])}** bugs detectados |
| Gate-level | {', '.join(r['teste'] + ' ' + r['status'] for r in v['gls']) or '—'} |
\"\"\"))
pd.DataFrame(S["physical"])[["label", "clock_period_ns", "clock_mhz", "setup_worst_slack_ns", "fmax_mhz_worst_corner",
                             "drc_klayout", "lvs_errors", "antenna_violations", "stdcell_area_um2", "power_total_w"]]"""),
    ("md", "## 6. Dashboard"),
    ("code", 'py("tools/build_dashboard.py")\nprint("Abra no navegador: dashboard/index.html")'),
])

# ---------------------------------------------------------------- 01
build("01_verificacao_rtl.ipynb", [
    ("md", """# 01 · Verificação do RTL

A verificação foi construída em camadas, cada uma cobrindo um tipo diferente de
risco (seção 7 do Plano Mestre):

1. **Testes unitários** — cada bloco isolado (ALU, regfile, LSU, multiplicador...).
2. **Testes dirigidos por instrução** — as 44 instruções fechadas, executadas no SoC,
   com scoreboard no banco de registradores. Foram eles que encontraram os
   **dois bugs reais de PC em JAL/JALR** (`docs/governance/DECISIONS.md`, ADR-003).
3. **Firmware** compilado com o GCC RISC-V real.
4. **Teste diferencial randomizado** — programas aleatórios executados no RTL e num
   **modelo de referência independente** (`tools/iss/rv32_iss.py`, escrito a partir
   da especificação RISC-V, não do RTL). Qualquer diferença na memória é um bug.
5. **Teste de mutação** — injeta bugs realistas no RTL e mede se a bateria os pega."""),
    ("code", SETUP),
    ("md", "## Regressão"),
    ("code", 'run("bash scripts/run_regression.sh", tail=25)\npd.read_csv(ROOT / "reports/regression_summary.csv")'),
    ("md", """## O modelo de referência (ISS)

O mesmo programa roda no modelo em Python. Abaixo, o firmware de smoke-test
executado no ISS: os registradores finais são o "gabarito" independente."""),
    ("code", """sys.path.insert(0, str(ROOT / "tools/iss"))
from rv32_iss import RV32ISS, load_hex
iss = RV32ISS(load_hex(ROOT / "firmware/build/smoke_test.hex")).run()
print(f"EBREAK apos {iss.steps} instrucoes, pc final = 0x{iss.pc:08x}")
print("assinatura na DMEM:", hex(iss.dmem_words(10)[8]), "(0x600dc0de = PASS)")
pd.DataFrame(sorted(iss.histogram.items(), key=lambda kv: -kv[1]), columns=["instrucao", "execucoes"]).head(12)"""),
    ("md", """## Cobertura do teste randomizado

Execuções por instrução no **corpo aleatório** dos programas (sem o prólogo e
o epílogo fixos). JALR, FENCE e ECALL ficam de fora do gerador e são cobertos
pelos testes dirigidos."""),
    ("code", """cov = pd.read_csv(ROOT / "docs/evidence/isa/random_coverage.csv").sort_values("execucoes", ascending=False)
fig, ax = plt.subplots(figsize=(12, 3.6))
ax.bar(cov["instrucao"], cov["execucoes"], color=SERIES[0], width=0.8)
style(ax, "Execucoes por instrucao nos programas aleatorios", ylabel="execucoes")
ax.grid(axis="x", visible=False)
plt.xticks(rotation=60, ha="right", fontsize=8, family="monospace")
plt.tight_layout(); plt.show()"""),
    ("md", """## Teste de mutação

Cada linha é um bug realista injetado no RTL. A barra mostra em quantos dos 20
programas aleatórios o bug foi detectado — basta um para "matar" o mutante.

Duas lacunas **no próprio gerador de testes** foram encontradas assim e corrigidas
(ver `versioning/HISTORICO.md`): o bit 11 do imediato de branch nunca era exercitado
(só havia saltos curtos para frente) e os loads quase sempre liam zero."""),
    ("code", """mut = pd.read_csv(ROOT / "reports/mutation.csv")
fig, ax = plt.subplots(figsize=(10, 4.2))
ax.barh(mut["mutante"][::-1], mut["programas_que_detectaram"][::-1], color=SERIES[0], height=0.6)
for i, v in enumerate(mut["programas_que_detectaram"][::-1]):
    ax.text(v + 0.2, i, f"{v}/20", va="center", fontsize=8, color="#52514e")
style(ax, f"Mutation score: {(mut['status'] == 'MORTO').sum()}/{len(mut)} bugs detectados", xlabel="programas que detectaram (de 20)")
ax.set_xlim(0, 21.5); ax.grid(axis="y", visible=False)
plt.tight_layout(); plt.show()"""),
])

# ---------------------------------------------------------------- 02
build("02_firmware.ipynb", [
    ("md", """# 02 · Firmware: da fonte à execução no processador

O firmware oficial da competição ainda não foi disponibilizado
(`docs/governance/SPEC_GAPS.md`, SG-05). Para provar a cadeia completa com
ferramentas reais, este firmware autoral em estilo `riscv-tests` testa 9 grupos
de instruções e grava uma assinatura na memória: `0x600DC0DE` se tudo passou,
`0xBAD00BAD` + número do teste se algo falhou."""),
    ("code", SETUP),
    ("code", 'print((ROOT / "firmware/smoke/smoke_test.S").read_text(encoding="utf-8")[:2600])'),
    ("md", "## Compilação (GCC RISC-V, `-march=rv32im`, sem instruções comprimidas) e simulação"),
    ("code", 'run("bash scripts/run_firmware_sim.sh", tail=6)'),
    ("code", """dis = (ROOT / "firmware/build/smoke_test.dis").read_text(encoding="utf-8").splitlines()
print("\\n".join(dis[:40]))"""),
    ("md", """## Waveforms

Início: cada instrução passa por **FETCH → DECODE → EXECUTE → WRITE-BACK**
(4 ciclos para ALU; loads usam também MEM_READ e MEM_WAIT, porque a DMEM é síncrona).
Fim: a assinatura `0x600DC0DE` é montada, gravada na DMEM e o EBREAK levanta `halt_o`."""),
    ("code", 'display(SVG(filename=str(ROOT / "docs/evidence/waveforms/firmware_inicio.svg")))'),
    ("code", 'display(SVG(filename=str(ROOT / "docs/evidence/waveforms/firmware_fim.svg")))'),
])

# ---------------------------------------------------------------- 03
build("03_fisico_openlane.ipynb", [
    ("md", """# 03 · Implementação física (OpenLane 2 · SKY130)

RTL → síntese (Yosys) → floorplan → posicionamento → árvore de clock → roteamento
→ análise de timing em 9 corners → DRC, LVS e antena → **GDSII**.

Alvo: `rv32_core` (o núcleo). As memórias de 4 MB / 8 kB do guia dependem da
macro física oficial (SPEC_GAPS SG-02) e não são sintetizadas em flip-flops.

Duas rodadas: **baseline** (40 ns, 25 MHz) e **opt30** (30 ns, 33 MHz, com reparo
de slew/capacitância depois do roteamento global).

> Cada rodada leva ~50 min e baixa o PDK SKY130 na primeira vez. Mude
> `RODAR_OPENLANE` para `True` para refazer."""),
    ("code", SETUP + "\nRODAR_OPENLANE = False"),
    ("code", """if RODAR_OPENLANE:
    run("bash scripts/run_openlane.sh openlane/config/config.json baseline", tail=15)
    run("bash scripts/run_openlane.sh openlane/config/config_opt30.json opt30", tail=15)
print((ROOT / "openlane/config/config_opt30.json").read_text())"""),
    ("md", "## Métricas das rodadas"),
    ("code", """S = summary()
cols = ["label", "clock_period_ns", "clock_mhz", "setup_worst_slack_ns", "fmax_mhz_worst_corner", "hold_worst_slack_ns",
        "drc_klayout", "drc_magic", "lvs_errors", "antenna_violations", "max_slew_violations", "max_cap_violations",
        "stdcell_area_um2", "die_area_um2", "utilization", "power_total_w"]
pd.DataFrame(S["physical"])[cols].set_index("label").T"""),
    ("md", """## Folga de setup por corner

Folga positiva = o sinal chega antes da borda do clock no caminho mais lento.
O corner `ss` (lento, 100 °C, 1,60 V) é sempre o pior."""),
    ("code", """runs = S["physical"]
corners = list(runs[0]["setup_ws_by_corner"])
fig, ax = plt.subplots(figsize=(10, 4))
w = 0.8 / len(runs)
for i, r in enumerate(runs):
    xs = [k + i * w for k in range(len(corners))]
    ax.bar(xs, [r["setup_ws_by_corner"][c] for c in corners], width=w * 0.92, color=SERIES[i],
           label=f"{r['label']} ({r['clock_period_ns']:.0f} ns)")
ax.set_xticks([k + w * (len(runs) - 1) / 2 for k in range(len(corners))])
ax.set_xticklabels([c.replace("_025C_1v80", "").replace("_100C_1v60", "").replace("_n40C_1v95", "") for c in corners],
                   family="monospace", fontsize=9)
style(ax, "Folga de setup por corner (ns)", ylabel="ns")
ax.axhline(0, color="#c3c2b7", linewidth=1); ax.legend(frameon=False); ax.grid(axis="x", visible=False)
plt.tight_layout(); plt.show()"""),
    ("md", "## Layout final (GDSII)"),
    ("code", 'display(Image(filename=str(ROOT / "docs/evidence/openlane/run_best/rv32_core_layout.png"), width=620))'),
    ("md", """## Gate-level: a netlist pós-layout é equivalente?

A netlist gerada pelo OpenLane (46 mil células `sky130_fd_sc_hd`) substitui o RTL
dentro do mesmo SoC e roda o firmware e os programas aleatórios."""),
    ("code", 'run("bash scripts/run_gls.sh", tail=8)\npd.read_csv(ROOT / "reports/gls_summary.csv")'),
])
