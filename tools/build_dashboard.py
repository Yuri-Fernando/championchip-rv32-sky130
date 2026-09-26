#!/usr/bin/env python3
"""
build_dashboard.py - Gera dashboard/index.html: painel autocontido (abre
offline no navegador, sem servidor e sem dependencias) com TODAS as
evidencias reais do projeto, lidas de reports/summary.json (gerado por
tools/build_reports.py), da imagem do layout GDSII e das waveforms SVG.

Uso: python tools/build_reports.py && python tools/build_dashboard.py
"""
from __future__ import annotations

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    summary = json.loads((ROOT / "reports/summary.json").read_text(encoding="utf-8"))
    ok = [r for r in summary["physical"] if r["drc_klayout"] == 0 and r["lvs_errors"] == 0 and r["setup_worst_slack_ns"] >= 0]
    # menor periodo; em empate, a rodada mais recente (a lista vem em ordem cronologica)
    best = min(reversed(ok), key=lambda r: r["clock_period_ns"]) if ok else summary["physical"][0]
    layout = ROOT / best["dir"] / "rv32_core_layout.png"
    if not layout.exists():
        layout = ROOT / "docs/evidence/openlane/run_best/rv32_core_layout.png"
    layout_uri = "data:image/png;base64," + base64.b64encode(layout.read_bytes()).decode() if layout.exists() else ""
    wf = {}
    for key in ("inicio", "fim"):
        p = ROOT / f"docs/evidence/waveforms/firmware_{key}.svg"
        wf[key] = p.read_text(encoding="utf-8") if p.exists() else "<p>waveform nao gerada</p>"

    html = TEMPLATE
    html = html.replace("__DATA__", json.dumps(summary, ensure_ascii=False).replace("</", "<\\/"))
    html = html.replace("__LAYOUT__", layout_uri)
    html = html.replace("__WF_INICIO__", wf["inicio"]).replace("__WF_FIM__", wf["fim"])
    out = ROOT / "dashboard/index.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(html, encoding="utf-8")
    print(f"{out.relative_to(ROOT)}: {len(html) / 1024:.0f} KB")


TEMPLATE = r"""<meta charset="utf-8">
<title>ChampionCHIP RV32 Tapeout</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chivo:wght@400;600;800&family=Chivo+Mono:wght@400;500&display=swap">
<style>
:root {
  color-scheme: light;
  --page: #f4f6f8; --surface: #ffffff; --surface-2: #eef1f4;
  --ink: #0f1419; --ink-2: #4a5360; --muted: #7b8490;
  --grid: #e2e6ea; --axis: #c2c9d0; --ring: rgba(15,20,25,0.10);
  --accent: #2a78d6;
  --s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a; --s4: #eda100;
  --good: #0a8a0a; --good-bg: #e3f4e3; --warn: #9a6400; --warn-bg: #fdf1d6;
  --crit: #b42f2f; --crit-bg: #fbe4e4;
  --mono: "Chivo Mono", ui-monospace, "Cascadia Mono", Consolas, monospace;
  --sans: "Chivo", system-ui, -apple-system, "Segoe UI", sans-serif;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    color-scheme: dark;
    --page: #0e1114; --surface: #161a1f; --surface-2: #1d2228;
    --ink: #f2f4f6; --ink-2: #b9c1ca; --muted: #8a939d;
    --grid: #262c33; --axis: #39414a; --ring: rgba(255,255,255,0.10);
    --accent: #3987e5; --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500;
    --good: #3fc43f; --good-bg: #13301a; --warn: #f0b429; --warn-bg: #33280f;
    --crit: #ec6a6a; --crit-bg: #3a1a1a;
  }
}
:root[data-theme="dark"] {
  color-scheme: dark;
  --page: #0e1114; --surface: #161a1f; --surface-2: #1d2228;
  --ink: #f2f4f6; --ink-2: #b9c1ca; --muted: #8a939d;
  --grid: #262c33; --axis: #39414a; --ring: rgba(255,255,255,0.10);
  --accent: #3987e5; --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500;
  --good: #3fc43f; --good-bg: #13301a; --warn: #f0b429; --warn-bg: #33280f;
  --crit: #ec6a6a; --crit-bg: #3a1a1a;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--ink); font-family: var(--sans); font-size: 15px; line-height: 1.5; }
.wrap { max-width: 1180px; margin: 0 auto; padding-inline: 20px; padding-block: 28px 64px; display: grid; gap: 28px; }
h1, h2, h3 { text-wrap: balance; margin: 0; }
h1 { font-weight: 800; font-size: clamp(28px, 4.2vw, 44px); letter-spacing: -0.02em; line-height: 1.05; }
h2 { font-weight: 800; font-size: 22px; letter-spacing: -0.01em; }
h3 { font-weight: 600; font-size: 15px; }
.eyebrow { font-family: var(--mono); font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }
.lede { color: var(--ink-2); max-width: 68ch; margin: 0; }
.mono { font-family: var(--mono); }
.num { font-variant-numeric: tabular-nums; }
header.id { display: grid; gap: 14px; padding-bottom: 8px; border-bottom: 1px solid var(--grid); }
.chips { display: flex; flex-wrap: wrap; gap: 8px; }
.chip { font-family: var(--mono); font-size: 12.5px; padding: 4px 10px; border-radius: 999px; background: var(--surface-2); color: var(--ink-2); border: 1px solid var(--ring); }
nav.toc { display: flex; flex-wrap: wrap; gap: 6px 18px; font-size: 14px; }
nav.toc a { color: var(--ink-2); text-decoration: none; border-bottom: 1px solid transparent; }
nav.toc a:hover, nav.toc a:focus-visible { color: var(--accent); border-bottom-color: var(--accent); outline: none; }
.kpis { display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 12px; }
.kpi { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 14px 16px; display: grid; gap: 4px; align-content: start; }
.kpi .v { font-size: 30px; font-weight: 800; letter-spacing: -0.02em; line-height: 1.1; }
.kpi .v small { font-size: 16px; font-weight: 600; color: var(--muted); }
.kpi .l { font-size: 13px; color: var(--ink-2); }
section { display: grid; gap: 14px; }
.sec-head { display: grid; gap: 4px; }
.panel { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 16px; display: grid; gap: 10px; min-width: 0; }
.grid2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 14px; }
.pill { display: inline-flex; align-items: center; gap: 5px; font-family: var(--mono); font-size: 12px; font-weight: 500; padding: 2px 8px; border-radius: 999px; white-space: nowrap; }
.pill.good { color: var(--good); background: var(--good-bg); }
.pill.warn { color: var(--warn); background: var(--warn-bg); }
.pill.crit { color: var(--crit); background: var(--crit-bg); }
.phases { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; }
.phase { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 12px; display: grid; gap: 6px; align-content: start; }
.phase .pid { font-family: var(--mono); font-size: 12px; color: var(--muted); display: flex; justify-content: space-between; align-items: center; gap: 6px; }
.phase .pn { font-weight: 600; font-size: 14px; }
.phase .pnote { font-size: 12.5px; color: var(--ink-2); }
table { border-collapse: collapse; width: 100%; font-size: 13.5px; }
th, td { text-align: left; padding: 7px 10px; border-bottom: 1px solid var(--grid); vertical-align: top; }
th { font-weight: 600; color: var(--ink-2); font-size: 12.5px; }
td.r, th.r { text-align: right; font-variant-numeric: tabular-nums; }
.scroll { overflow-x: auto; }
.isa { display: grid; gap: 10px; }
.isa-row { display: grid; grid-template-columns: 110px 1fr; gap: 10px; align-items: start; }
.isa-cat { font-size: 12.5px; color: var(--ink-2); padding-top: 5px; }
.isa-cells { display: flex; flex-wrap: wrap; gap: 5px; }
.cell { font-family: var(--mono); font-size: 12px; padding: 4px 7px; border-radius: 6px; border: 1px solid var(--ring); cursor: default; }
.cell.good { background: var(--good-bg); color: var(--good); }
.cell.warn { background: var(--warn-bg); color: var(--warn); }
svg.chart { width: 100%; height: auto; display: block; overflow: visible; }
svg.chart text { fill: var(--ink-2); font-family: var(--sans); font-size: 12px; }
svg.chart .val { fill: var(--ink); font-family: var(--mono); font-size: 11.5px; }
svg.chart .gridline { stroke: var(--grid); }
svg.chart .baseline { stroke: var(--axis); }
.legend { display: flex; flex-wrap: wrap; gap: 14px; font-size: 13px; color: var(--ink-2); }
.legend i { display: inline-block; width: 12px; height: 12px; border-radius: 3px; margin-right: 6px; vertical-align: -1px; }
.wave { overflow-x: auto; color: var(--ink); background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 10px; }
.wave svg { display: block; }
.note { font-size: 13px; color: var(--ink-2); margin: 0; }
figure { margin: 0; display: grid; gap: 8px; }
figure img { width: 100%; max-width: 100%; border-radius: 8px; border: 1px solid var(--ring); background: #000; }
figcaption { font-size: 13px; color: var(--ink-2); }
details summary { cursor: pointer; font-size: 13px; color: var(--accent); }
details summary:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
#tip { position: fixed; pointer-events: none; z-index: 10; background: var(--ink); color: var(--page); font-family: var(--mono); font-size: 12px; padding: 6px 9px; border-radius: 6px; max-width: 280px; }
.gap-list { display: grid; gap: 8px; }
.gap { display: grid; grid-template-columns: 64px 1fr auto; gap: 10px; align-items: center; background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 10px 14px; }
.gap .gid { font-family: var(--mono); font-size: 13px; color: var(--muted); }
.gap .gt { font-size: 14px; }
.gap .gs { font-size: 12.5px; color: var(--ink-2); }
footer { font-size: 12.5px; color: var(--muted); border-top: 1px solid var(--grid); padding-top: 14px; }
@media (max-width: 560px) {
  .isa-row { grid-template-columns: 1fr; gap: 4px; }
  .gap { grid-template-columns: 1fr; gap: 4px; }
}
</style>

<div class="wrap">
  <header class="id">
    <div class="eyebrow">ChampionCHIP eXperience · Fase 2 · painel de verificação e tapeout</div>
    <h1>RV32I · Zmmul · Xicrc</h1>
    <p class="lede">Microcontrolador RISC-V de 32 bits, núcleo multicycle, levado do RTL ao GDSII no processo SkyWater 130 nm. Todos os números abaixo são lidos dos artefatos reais do repositório (logs de simulação, métricas do OpenLane, testes de mutação).</p>
    <div class="chips" id="chips"></div>
    <nav class="toc" aria-label="Seções">
      <a href="#fases">Fases</a><a href="#verificacao">Verificação</a><a href="#isa">Matriz da ISA</a>
      <a href="#firmware">Firmware</a><a href="#fisico">Físico</a><a href="#lacunas">Lacunas</a>
    </nav>
  </header>

  <div class="kpis" id="kpis" aria-label="Resumo"></div>

  <section id="fases">
    <div class="sec-head"><div class="eyebrow">Plano Mestre · seção 9</div><h2>Fases F0 a F10</h2></div>
    <div class="phases" id="phases"></div>
  </section>

  <section id="verificacao">
    <div class="sec-head"><div class="eyebrow">RTL · Icarus Verilog + modelo de referência em Python</div><h2>Verificação</h2>
      <p class="lede">Quatro camadas: testes unitários, testes dirigidos por instrução, firmware compilado com o GCC RISC-V e programas aleatórios comparados contra um simulador de instruções escrito a partir da especificação. O teste de mutação mede se essa bateria realmente pega bugs.</p></div>
    <div class="grid2">
      <div class="panel"><h3>Suítes de regressão</h3><div class="scroll"><table id="t-reg"></table></div></div>
      <div class="panel"><h3>Teste de mutação: programas aleatórios que detectaram cada bug injetado</h3>
        <svg class="chart" id="c-mut" role="img" aria-label="Detecções por mutante"></svg>
        <p class="note" id="mut-note"></p></div>
    </div>
    <div class="panel"><h3>Cobertura do corpo aleatório: execuções por instrução (todos os programas)</h3>
      <svg class="chart" id="c-cov" role="img" aria-label="Execuções por instrução nos programas aleatórios"></svg>
      <details><summary>Ver tabela</summary><div class="scroll"><table id="t-cov"></table></div></details></div>
  </section>

  <section id="isa">
    <div class="sec-head"><div class="eyebrow">47 instruções-alvo do guia oficial</div><h2>Matriz da ISA</h2></div>
    <div class="panel"><div class="isa" id="isa-grid"></div>
      <div class="legend"><span><span class="pill good">✓ PASS</span> teste dirigido + regressão</span><span><span class="pill warn">⏸ BLOCKED</span> semântica não especificada no guia (SG-01)</span></div></div>
  </section>

  <section id="firmware">
    <div class="sec-head"><div class="eyebrow">GCC RISC-V → ELF → hex → simulação</div><h2>Firmware em execução</h2>
      <p class="lede">Cada instrução percorre FETCH, DECODE, EXECUTE e WRITE-BACK. No fim, o firmware grava a assinatura <span class="mono">0x600DC0DE</span> na memória de dados e executa EBREAK, que levanta <span class="mono">halt_o</span>.</p></div>
    <div class="wave">__WF_INICIO__</div>
    <div class="wave">__WF_FIM__</div>
  </section>

  <section id="fisico">
    <div class="sec-head"><div class="eyebrow">OpenLane 2 · sky130A · sky130_fd_sc_hd</div><h2>Implementação física</h2>
      <p class="lede">Síntese, posicionamento, árvore de clock, roteamento e verificação de sign-off. Folga de setup positiva significa que o sinal chega antes da borda do clock em todos os caminhos. As três primeiras rodadas usaram restrições só de clock e I/O (clock ideal, limite de slew de 1,5 ns); a final usa o SDC de sign-off completo (clock propagado, derating de 5 %, limite de 0,75 ns), por isso a folga é menor e mais realista.</p></div>
    <div class="grid2">
      <div class="panel"><h3>Folga de setup por corner (ns)</h3>
        <div class="legend" id="slack-legend"></div>
        <svg class="chart" id="c-slack" role="img" aria-label="Folga de setup por corner de processo"></svg>
        <p class="note">Corners: <span class="mono">ss</span> lento (100 °C, 1,60 V), <span class="mono">tt</span> típico (25 °C, 1,80 V), <span class="mono">ff</span> rápido (−40 °C, 1,95 V).</p></div>
      <figure class="panel"><img id="layout" alt="Layout físico do rv32_core renderizado a partir do GDSII" src="__LAYOUT__">
        <figcaption id="layout-cap"></figcaption></figure>
    </div>
    <div class="panel"><h3>Comparação entre rodadas</h3><div class="scroll"><table id="t-phys"></table></div></div>
    <div class="panel" id="sweep-panel" hidden><h3>Varredura: onde está o limite</h3>
      <p class="lede" id="sweep-lede"></p><div class="scroll"><table id="t-sweep"></table></div></div>
  </section>

  <section id="lacunas">
    <div class="sec-head"><div class="eyebrow">docs/governance/SPEC_GAPS.md</div><h2>Lacunas do guia oficial</h2>
      <p class="lede">Pontos que o guia não especifica. Nenhum foi preenchido por suposição: cada um está isolado e marcado no código até o material oficial chegar.</p></div>
    <div class="gap-list" id="gaps"></div>
  </section>

  <footer id="foot"></footer>
</div>
<div id="tip" hidden></div>

<script>
const D = __DATA__;
const $ = s => document.querySelector(s);
const esc = s => String(s ?? "").replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const fmt = (n, d = 0) => n == null ? "—" : Number(n).toLocaleString("pt-BR", {minimumFractionDigits: d, maximumFractionDigits: d});
const pill = (lvl, txt) => `<span class="pill ${lvl}">${lvl === "good" ? "✓" : lvl === "warn" ? "⏸" : "✕"} ${esc(txt)}</span>`;
const tip = $("#tip");
function bindTip(el, text) {
  el.addEventListener("mousemove", e => { tip.hidden = false; tip.textContent = text; tip.style.left = (e.clientX + 12) + "px"; tip.style.top = (e.clientY + 12) + "px"; });
  el.addEventListener("mouseleave", () => { tip.hidden = true; });
}
const NS = "http://www.w3.org/2000/svg";
function sv(tag, attrs, parent) { const n = document.createElementNS(NS, tag); for (const k in attrs) n.setAttribute(k, attrs[k]); parent && parent.appendChild(n); return n; }

const runs = D.physical;
const base = runs.find(r => r.label === "baseline") || runs[0];
const best = runs.filter(r => r.drc_klayout === 0 && r.lvs_errors === 0 && r.setup_worst_slack_ns >= 0)
                 .reverse().sort((a, b) => a.clock_period_ns - b.clock_period_ns)[0] || base;  // empate: a mais recente
const V = D.verification;
const randomRow = V.regression.find(r => r.suite === "random");
const glsOk = V.gls.length && V.gls.every(r => r.status === "PASS");
const sdfRows = (V.gls_sdf || []).filter(r => !r.teste.startsWith("controle"));
const sdfOk = sdfRows.length && sdfRows.every(r => r.status === "PASS");
const sdfNeg = (V.gls_sdf || []).find(r => r.teste.startsWith("controle"));
const sdfPill = r => r.teste.startsWith("controle")
  ? pill(r.status === "FALHOU COMO ESPERADO" ? "good" : "crit", r.status === "FALHOU COMO ESPERADO" ? "falhou (esperado)" : r.status)
  : pill(r.status === "PASS" ? "good" : "crit", r.status);

// ---- identidade + KPIs --------------------------------------------------
const die = best ? Math.sqrt(best.die_area_um2) : null;
$("#chips").innerHTML = [
  "sky130A · 130 nm", "sky130_fd_sc_hd", "multicycle · FSM 16 estados",
  best ? `die ${fmt(best.die_area_um2 / 1e6, 2)} mm²` : null,
  best ? `clock ${fmt(best.clock_mhz, 1)} MHz` : null,
  "IMEM 0x0040_0000 · DMEM 0x1001_0000"
].filter(Boolean).map(t => `<span class="chip">${esc(t)}</span>`).join("");

const kpis = [
  [`${D.isa.closed}<small>/${D.isa.total}</small>`, "instruções fechadas (RV32I 40/40 · Zmmul 4/4)"],
  [`${V.regression_pass}<small>/${V.regression.length}</small>`, "suítes de regressão PASS"],
  [randomRow ? (randomRow.status === "PASS" ? `${randomRow.teste.split(" ")[0]}<small>/${randomRow.teste.split(" ")[0]}</small>` : "FALHA") : "—",
   randomRow ? `programas aleatórios (${randomRow.teste.split(" x ")[1] || ""}) idênticos ao modelo de referência` : "teste diferencial"],
  [`${V.mutation_killed}<small>/${V.mutation.length}</small>`, "bugs injetados detectados (mutation score)"],
  [glsOk && (!sdfRows.length || sdfOk) ? "PASS" : (V.gls.length ? "FALHA" : "—"), sdfRows.length ? "gate-level da netlist pós-layout, com atrasos reais (SDF) nos corners extremos" : "simulação gate-level da netlist pós-layout"],
  [best ? `${fmt(best.drc_klayout)}·${fmt(best.lvs_errors)}` : "—", "erros DRC · LVS no GDSII final"],
  [best ? `${fmt(best.clock_mhz, 1)}<small> MHz</small>` : "—", `timing fechado em todos os corners (folga ${best ? fmt(best.setup_worst_slack_ns, 2) : "—"} ns)`],
];
$("#kpis").innerHTML = kpis.map(([v, l]) => `<div class="kpi"><div class="v num">${v}</div><div class="l">${esc(l)}</div></div>`).join("");

// ---- fases ------------------------------------------------------------
const PH = {done: ["good", "concluída"], partial: ["warn", "parcial"], todo: ["crit", "pendente"]};
$("#phases").innerHTML = D.phases.map(p => `<div class="phase"><div class="pid"><span>${esc(p.id)}</span>${pill(PH[p.status][0], PH[p.status][1])}</div><div class="pn">${esc(p.name)}</div><div class="pnote">${esc(p.note)}</div></div>`).join("");

// ---- regressao ------------------------------------------------------------
$("#t-reg").innerHTML = `<thead><tr><th>Suíte</th><th>Teste</th><th>Resultado</th></tr></thead><tbody>` +
  V.regression.map(r => `<tr><td>${esc(r.suite)}</td><td class="mono">${esc(r.teste)}</td><td>${pill(r.status === "PASS" ? "good" : "crit", r.status)}</td></tr>`).join("") +
  V.gls.map(r => `<tr><td>gate-level</td><td class="mono">${esc(r.teste)}</td><td>${pill(r.status === "PASS" ? "good" : "crit", r.status)}</td></tr>`).join("") +
  (V.gls_sdf || []).map(r => `<tr><td>gate-level SDF</td><td class="mono">${esc(r.corner.replace("_100C_1v60", "").replace("_n40C_1v95", "").replace("_025C_1v80", ""))} · ${esc(r.teste)}</td><td>${sdfPill(r)}</td></tr>`).join("") + `</tbody>`;

// ---- barras horizontais (serie unica) -------------------------------------
function hbars(svgSel, rows, max, fmtVal, tipText) {
  const svg = $(svgSel), W = 560, rowH = 24, padL = 214, padR = 44, H = rows.length * rowH + 8;
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  const x = v => padL + (W - padL - padR) * v / max;
  sv("line", {x1: padL, x2: padL, y1: 0, y2: H - 4, class: "baseline"}, svg);
  rows.forEach((r, i) => {
    const y = i * rowH + 4, h = rowH - 8;
    const t = sv("text", {x: padL - 8, y: y + h / 2 + 4, "text-anchor": "end"}, svg); t.textContent = r.label;
    const w = Math.max(2, x(r.value) - padL);
    const bar = sv("path", {d: `M${padL},${y} h${w - 4} a4,4 0 0 1 4,4 v${h - 8} a4,4 0 0 1 -4,4 h${-(w - 4)} z`, fill: "var(--s1)"}, svg);
    const hit = sv("rect", {x: padL, y: y - 3, width: W - padL, height: rowH, fill: "transparent"}, svg);
    bindTip(hit, tipText(r));
    const vt = sv("text", {x: padL + w + 6, y: y + h / 2 + 4, class: "val"}, svg); vt.textContent = fmtVal(r.value);
  });
}
const nSeeds = V.mutation.length ? Number(V.mutation[0].programas_total) : 20;
hbars("#c-mut", V.mutation.map(m => ({label: m.mutante, value: Number(m.programas_que_detectaram), m})), nSeeds,
      v => `${v}/${nSeeds}`, r => `${r.label}\n${r.m.arquivo}\ndetectado em ${r.value} de ${nSeeds} programas · ${r.m.status}`);
$("#mut-note").textContent = `Mutation score: ${V.mutation_killed} de ${V.mutation.length} bugs detectados. Bastaria um programa para o bug ser pego; barras longas indicam bugs fáceis de expor.`;

const cov = V.random_coverage.slice().sort((a, b) => b.execucoes - a.execucoes);
(function vbars() {
  const svg = $("#c-cov"), W = 1100, H = 250, padL = 40, padB = 58, padT = 10;
  const max = Math.max(...cov.map(c => c.execucoes));
  const step = Math.pow(10, Math.floor(Math.log10(max))) / (max / Math.pow(10, Math.floor(Math.log10(max))) > 5 ? 1 : 2);
  const top = Math.ceil(max / step) * step;
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  const y = v => padT + (H - padT - padB) * (1 - v / top);
  for (let t = 0; t <= top; t += step) {
    sv("line", {x1: padL, x2: W, y1: y(t), y2: y(t), class: t === 0 ? "baseline" : "gridline"}, svg);
    const tt = sv("text", {x: padL - 6, y: y(t) + 4, "text-anchor": "end"}, svg); tt.textContent = fmt(t);
  }
  const bw = (W - padL) / cov.length;
  cov.forEach((c, i) => {
    const x0 = padL + i * bw + 1, w = bw - 2, y0 = y(c.execucoes), h = y(0) - y0;
    sv("path", {d: `M${x0},${y(0)} v${-(h - 4)} a4,4 0 0 1 4,-4 h${w - 8} a4,4 0 0 1 4,4 v${h - 4} z`, fill: "var(--s1)"}, svg);
    const hit = sv("rect", {x: x0 - 1, y: padT, width: bw, height: H - padT - padB, fill: "transparent"}, svg);
    bindTip(hit, `${c.instrucao}: ${fmt(c.execucoes)} execuções`);
    const lx = x0 + w / 2, ly = y(0) + 10;
    const t = sv("text", {x: lx, y: ly, "text-anchor": "end", transform: `rotate(-55 ${lx} ${ly})`, class: "mono"}, svg);
    t.textContent = c.instrucao;
  });
})();
$("#t-cov").innerHTML = `<thead><tr><th>Instrução</th><th class="r">Execuções</th></tr></thead><tbody>` +
  cov.map(c => `<tr><td class="mono">${esc(c.instrucao)}</td><td class="r">${fmt(c.execucoes)}</td></tr>`).join("") + `</tbody>`;

// ---- matriz ISA --------------------------------------------------------------
const cats = [...new Set(D.isa.matrix.map(r => r.categoria))];
$("#isa-grid").innerHTML = cats.map(c => `<div class="isa-row"><div class="isa-cat">${esc(c)}</div><div class="isa-cells">` +
  D.isa.matrix.filter(r => r.categoria === c).map(r => {
    const ok = r.status.startsWith("PASS");
    return `<span class="cell ${ok ? "good" : "warn"}" title="${esc(r.instrucao)} · ${esc(r.status)} · ${esc(r.testbench)}">${ok ? "✓" : "⏸"} ${esc(r.instrucao)}</span>`;
  }).join("") + `</div></div>`).join("");

// ---- folga por corner (barras agrupadas) ----------------------------------
(function slack() {
  const svg = $("#c-slack");
  const corners = Object.keys(base.setup_ws_by_corner);
  const series = runs.map((r, i) => ({run: r, color: `var(--s${Math.min(i + 1, 4)})`, name: `${r.label} · ${fmt(r.clock_period_ns)} ns`}));
  $("#slack-legend").innerHTML = series.map(s => `<span><i style="background:${s.color}"></i>${esc(s.name)}</span>`).join("");
  const W = 560, padL = 118, padR = 40, rowH = 12 * series.length + 14, H = corners.length * rowH + 30;
  const max = Math.max(...runs.flatMap(r => Object.values(r.setup_ws_by_corner).map(Number)));
  const niceMax = Math.ceil(max / 5) * 5;
  svg.setAttribute("viewBox", `0 0 ${W} ${H}`);
  const x = v => padL + (W - padL - padR) * v / niceMax;
  for (let t = 0; t <= niceMax; t += 5) {
    sv("line", {x1: x(t), x2: x(t), y1: 0, y2: H - 22, class: t === 0 ? "baseline" : "gridline"}, svg);
    const tt = sv("text", {x: x(t), y: H - 6, "text-anchor": "middle"}, svg); tt.textContent = t;
  }
  corners.forEach((c, ci) => {
    const y0 = ci * rowH + 4;
    const lab = sv("text", {x: padL - 8, y: y0 + rowH / 2 + 1, "text-anchor": "end", class: "mono"}, svg); lab.textContent = c.replace("_025C_1v80", "").replace("_100C_1v60", "").replace("_n40C_1v95", "");
    series.forEach((s, si) => {
      const v = Number(s.run.setup_ws_by_corner[c]);
      const y = y0 + si * 12, w = Math.max(2, x(v) - padL);
      sv("path", {d: `M${padL},${y} h${w - 3} a3,3 0 0 1 3,3 v4 a3,3 0 0 1 -3,3 h${-(w - 3)} z`, fill: s.color}, svg);
      const hit = sv("rect", {x: padL, y: y - 1, width: W - padL, height: 12, fill: "transparent"}, svg);
      bindTip(hit, `${s.name}\n${c}\nfolga de setup: ${fmt(v, 2)} ns`);
    });
  });
})();

// ---- tabela fisica ---------------------------------------------------------
const rowsP = [
  ["Restrições (SDC)", r => r.sdc_complete ? "completas" : "só clock e I/O"],
  ["Período de clock", r => `${fmt(r.clock_period_ns)} ns (${fmt(r.clock_mhz, 1)} MHz)`],
  ["Folga de setup, pior corner", r => `${fmt(r.setup_worst_slack_ns, 2)} ns`],
  ["Fmax estimada no pior corner", r => `${fmt(r.fmax_mhz_worst_corner, 1)} MHz`],
  ["Folga de hold, pior corner", r => `${fmt(r.hold_worst_slack_ns, 3)} ns`],
  ["DRC (KLayout / Magic)", r => `${fmt(r.drc_klayout)} / ${fmt(r.drc_magic)}`],
  ["Erros de LVS", r => fmt(r.lvs_errors)],
  ["Violações de antena", r => fmt(r.antenna_violations)],
  ["Violações max slew (limite)", r => `${fmt(r.max_slew_violations)} (${fmt(r.slew_limit_ns, 2)} ns)`],
  ["Violações max cap / fanout", r => `${fmt(r.max_cap_violations)} / ${r.sdc_complete ? fmt(r.max_fanout_violations) : "—"}`],
  ["Células (diodos de antena)", r => `${fmt(r.instances)} (${fmt(r.antenna_diodes)})`],
  ["Área de standard cells", r => `${fmt(r.stdcell_area_um2)} µm²`],
  ["Área do die", r => `${fmt(r.die_area_um2)} µm²`],
  ["Utilização", r => `${fmt(r.utilization * 100, 1)} %`],
  ["Potência total estimada", r => `${fmt(r.power_total_w * 1000, 1)} mW`],
  ["Comprimento de fio roteado", r => `${fmt(r.wirelength_um / 1000, 0)} mm`],
];
$("#t-phys").innerHTML = `<thead><tr><th>Métrica</th>${runs.map(r => `<th class="r">${esc(r.label)}</th>`).join("")}</tr></thead><tbody>` +
  rowsP.map(([n, f]) => `<tr><td>${esc(n)}</td>${runs.map(r => `<td class="r mono">${f(r)}</td>`).join("")}</tr>`).join("") + `</tbody>`;
// ---- varredura ------------------------------------------------------------
const SW = D.sweep || [];
if (SW.length) {
  const ref = runs.find(r => r.label === "final");
  const rowsS = (ref ? [ref] : []).concat(SW);
  const ok = r => r.setup_worst_slack_ns >= 0 && r.drc_klayout === 0 && r.lvs_errors === 0;
  $("#sweep-panel").hidden = false;
  $("#sweep-lede").textContent = "Mesma configuração da rodada final, mudando só o período de clock ou a utilização do núcleo. Uma rodada só conta se fecha setup no pior corner com o SDC de sign-off.";
  $("#t-sweep").innerHTML = `<thead><tr><th>Rodada</th><th class="r">Clock</th><th class="r">Utilização</th><th class="r">Folga de setup</th><th class="r">Caminhos violando</th><th class="r">DRC · LVS</th><th class="r">Antena</th><th class="r">Área do die</th><th>Timing</th></tr></thead><tbody>` +
    rowsS.map(r => `<tr><td>${esc(r.label)}</td><td class="r mono">${fmt(r.clock_period_ns)} ns (${fmt(r.clock_mhz, 1)} MHz)</td><td class="r mono">${fmt(r.core_util_pct)} %</td><td class="r mono">${fmt(r.setup_worst_slack_ns, 2)} ns</td><td class="r mono">${fmt(r.setup_violations)}</td><td class="r mono">${fmt(r.drc_klayout)} · ${fmt(r.lvs_errors)}</td><td class="r mono">${fmt(r.antenna_violations)}</td><td class="r mono">${fmt(r.die_area_um2 / 1e6, 3)} mm²</td><td>${ok(r) ? pill("good", "fechado") : pill("crit", "viola setup")}</td></tr>`).join("") + `</tbody>`;
}

if (best) $("#layout-cap").textContent = `GDSII do rv32_core (rodada ${best.label}, ${fmt(best.clock_period_ns)} ns): die de ${fmt(best.die_w_um, 1)} × ${fmt(best.die_h_um, 1)} µm, ${fmt(best.instances)} instâncias de células, renderizado com o KLayout.`;

// ---- lacunas -------------------------------------------------------------
const GL = {blocked: ["crit", "bloqueada"], partial: ["warn", "mitigada"], done: ["good", "resolvida"]};
$("#gaps").innerHTML = D.spec_gaps.map(g => `<div class="gap"><div class="gid">${esc(g.id)}</div><div><div class="gt">${esc(g.title)}</div><div class="gs">${esc(g.status)}</div></div>${pill(GL[g.level][0], GL[g.level][1])}</div>`).join("");

$("#foot").innerHTML = `Gerado em ${esc(D.generated)} por <span class="mono">tools/build_dashboard.py</span> a partir de <span class="mono">reports/summary.json</span>. Fonte das métricas físicas: <span class="mono">docs/evidence/openlane/run_*/metrics.json</span>.`;
</script>
"""

if __name__ == "__main__":
    main()
