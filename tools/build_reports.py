#!/usr/bin/env python3
"""
build_reports.py - Agrega TODAS as evidencias reais do projeto em
reports/summary.json (fonte unica do dashboard e dos notebooks) e gera
reports/physical_sweep.csv + reports/RESUMO.md.

Le: docs/governance/TEST_MATRIX.csv, docs/governance/SPEC_GAPS.md,
reports/regression_summary.csv, reports/mutation.csv, reports/gls_summary.csv,
docs/evidence/isa/random_coverage.csv, docs/evidence/openlane/run_*/metrics.json
(+ config.json). Nada e digitado a mao aqui alem do status das fases F0-F10.

Sem dependencias externas. Uso: python tools/build_reports.py
"""
from __future__ import annotations

import csv
import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORNERS = ["nom_tt_025C_1v80", "min_tt_025C_1v80", "max_tt_025C_1v80",
           "nom_ss_100C_1v60", "min_ss_100C_1v60", "max_ss_100C_1v60",
           "nom_ff_n40C_1v95", "min_ff_n40C_1v95", "max_ff_n40C_1v95"]

# Status das fases do Plano Mestre (secao 9). Unica informacao "editorial".
PHASES = [
    ("F0", "Freeze de especificação", "done", "Inventário do guia + 5 lacunas documentadas"),
    ("F1", "Skeleton e automação", "done", "14 módulos RTL, Docker, scripts portáveis, CI"),
    ("F2", "Módulos unitários", "done", "8 testbenches unitários"),
    ("F3", "FSM + core integrado", "done", "FSM de 16 estados, datapath multicycle"),
    ("F4", "Fechamento RV32I", "done", "40/40 instruções com teste dirigido"),
    ("F5", "Zmmul + Xicrc", "partial", "Zmmul 4/4; Xicrc bloqueada por especificação (SG-01)"),
    ("F6", "Firmware", "partial", "Firmware autoral PASS; oficial indisponível (SG-05)"),
    ("F7", "OpenLane baseline", "done", "GDSII com DRC 0, LVS 0, timing fechado"),
    ("F8", "Otimização física", "done", "30 ns (33,3 MHz) com SDC de sign-off completo: nenhum pino acima do limite de slew da biblioteca; antena e cap residuais"),
    ("F9", "Gate-level regression", "done", "Netlists das 4 rodadas equivalentes ao modelo de referência"),
    ("F10", "Relatório / vídeo / submissão", "partial", "Relatório, dashboard, notebooks, slides e roteiro prontos; vídeo a gravar"),
]


def read_csv(path: Path) -> list[dict]:
    if not path.exists():
        return []
    with open(path, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def physical_runs() -> list[dict]:
    runs = []
    for d in sorted((ROOT / "docs/evidence/openlane").glob("run_*")):
        mfile = d / "metrics.json"
        if not mfile.exists():
            continue
        m = json.loads(mfile.read_text(encoding="utf-8"))
        cfg = json.loads((d / "config.json").read_text(encoding="utf-8")) if (d / "config.json").exists() else {}
        period = float(cfg.get("CLOCK_PERIOD", 0) or 0)
        wss = m.get("timing__setup__ws")
        label = "baseline" if d.name == "run_best" else d.name.replace("run_", "")
        # SDC usado: signoff.sdc (completo, limite de transição 0,75 ns) ou base.sdc
        # (só clock e I/O: vale o limite da biblioteca, 1,5 ns, e clock ideal)
        sdc = str(cfg.get("PNR_SDC_FILE") or cfg.get("FALLBACK_SDC_FILE") or "").rsplit("/", 1)[-1]
        full_sdc = sdc == "signoff.sdc"
        runs.append({
            "label": label,
            "dir": d.relative_to(ROOT).as_posix(),
            "clock_period_ns": period,
            "clock_mhz": round(1000 / period, 1) if period else None,
            "fmax_mhz_worst_corner": round(1000 / (period - wss), 1) if period and wss is not None and period > wss else None,
            "setup_worst_slack_ns": wss,
            "setup_ws_by_corner": {c: m.get(f"timing__setup__ws__corner:{c}") for c in CORNERS},
            "hold_worst_slack_ns": m.get("timing__hold__ws"),
            "setup_tns": m.get("timing__setup__tns"),
            "hold_tns": m.get("timing__hold__tns"),
            "drc_klayout": m.get("klayout__drc_error__count"),
            "drc_magic": m.get("magic__drc_error__count"),
            "lvs_errors": m.get("design__lvs_error__count"),
            "antenna_violations": m.get("route__antenna_violation__count"),
            "max_slew_violations": m.get("design__max_slew_violation__count"),
            "max_cap_violations": m.get("design__max_cap_violation__count"),
            "max_fanout_violations": m.get("design__max_fanout_violation__count"),
            "sdc": sdc,
            "sdc_complete": full_sdc,
            "slew_limit_ns": float(cfg.get("MAX_TRANSITION_CONSTRAINT", 0.75)) if full_sdc else 1.5,
            "antenna_diodes": m.get("design__instance__count__class:antenna_cell"),
            "core_area_um2": m.get("design__core__area"),
            "die_area_um2": m.get("design__die__area"),
            "die_w_um": float(m["design__die__bbox"].split()[2]) if m.get("design__die__bbox") else None,
            "die_h_um": float(m["design__die__bbox"].split()[3]) if m.get("design__die__bbox") else None,
            "stdcell_area_um2": m.get("design__instance__area__stdcell"),
            "utilization": m.get("design__instance__utilization"),
            "instances": m.get("design__instance__count"),
            "power_total_w": m.get("power__total"),
            "wirelength_um": m.get("route__wirelength"),
            "config": {k: cfg[k] for k in cfg if k not in ("VERILOG_FILES", "VERILOG_INCLUDE_DIRS")},
        })
    order = {"baseline": 0, "opt30": 1, "sem_diodos": 2, "final": 3}  # ordem cronologica das rodadas
    return sorted(runs, key=lambda r: (order.get(r["label"], 2.5), r["label"]))


def spec_gaps() -> list[dict]:
    path = ROOT / "docs/governance/SPEC_GAPS.md"
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    gaps = []
    for block in re.split(r"\n## ", text)[1:]:
        head = block.splitlines()[0]
        mid = re.match(r"(SG-\d+)\s+[—-]\s+(.*)", head)
        st = re.search(r"\*\*Status:\*\*\s*(.*)", block)
        if mid:
            status_txt = st.group(1).strip() if st else ""
            level = "blocked" if "🔴" in status_txt else ("partial" if "🟡" in status_txt else "done")
            gaps.append({"id": mid.group(1), "title": mid.group(2).strip(),
                         "status": re.sub(r"[🔴🟡🟢]\s*", "", status_txt), "level": level})
    return gaps


def main() -> None:
    matrix = read_csv(ROOT / "docs/governance/TEST_MATRIX.csv")
    isa_pass = sum(1 for r in matrix if r["status"].startswith("PASS"))
    regression = read_csv(ROOT / "reports/regression_summary.csv")
    mutation = read_csv(ROOT / "reports/mutation.csv")
    gls = read_csv(ROOT / "reports/gls_summary.csv")
    coverage = read_csv(ROOT / "docs/evidence/isa/random_coverage.csv")
    runs = physical_runs()

    summary = {
        "generated": date.today().isoformat(),
        "project": {
            "name": "RV32I_Zmmul_Xicrc",
            "competition": "ChampionCHIP eXperience - Fase 2",
            "microarchitecture": "multicycle, FSM de 16 estados",
            "pdk": "SkyWater SKY130 (sky130A / sky130_fd_sc_hd)",
            "memory_map": {"IMEM": "0x0040_0000 (ROM, ate 4 MB)", "DMEM": "0x1001_0000 (SRAM sincrona, 8 kB)"},
        },
        "isa": {
            "total": len(matrix), "closed": isa_pass,
            "rv32i": sum(1 for r in matrix if r["status"].startswith("PASS") and r["categoria"] not in ("Zmmul", "Xicrc")),
            "zmmul": sum(1 for r in matrix if r["status"].startswith("PASS") and r["categoria"] == "Zmmul"),
            "xicrc_blocked": sum(1 for r in matrix if "BLOCKED" in r["status"]),
            "matrix": matrix,
        },
        "verification": {
            "regression": regression,
            "regression_pass": sum(1 for r in regression if r["status"] == "PASS"),
            "mutation": mutation,
            "mutation_killed": sum(1 for r in mutation if r["status"] == "MORTO"),
            "gls": gls,
            "random_coverage": [{"instrucao": r["instrucao"], "execucoes": int(r["execucoes"])} for r in coverage],
        },
        "physical": runs,
        "phases": [{"id": a, "name": b, "status": c, "note": d} for a, b, c, d in PHASES],
        "spec_gaps": spec_gaps(),
    }
    out = ROOT / "reports"
    out.mkdir(exist_ok=True)
    (out / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

    with open(out / "physical_sweep.csv", "w", newline="", encoding="utf-8") as f:
        cols = ["label", "sdc", "slew_limit_ns", "clock_period_ns", "clock_mhz", "setup_worst_slack_ns", "fmax_mhz_worst_corner",
                "drc_klayout", "drc_magic", "lvs_errors", "antenna_violations", "antenna_diodes", "max_slew_violations",
                "max_cap_violations", "max_fanout_violations", "instances", "core_area_um2", "stdcell_area_um2",
                "utilization", "power_total_w", "wirelength_um"]
        w = csv.DictWriter(f, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(runs)

    lines = [f"# Resumo de evidencias (gerado em {summary['generated']} por tools/build_reports.py)", "",
             f"- ISA: **{isa_pass}/{len(matrix)}** instrucoes fechadas",
             f"- Regressao: **{summary['verification']['regression_pass']}/{len(regression)}** suites PASS",
             f"- Teste de mutacao: **{summary['verification']['mutation_killed']}/{len(mutation)}** mutantes detectados",
             f"- Gate-level: " + (", ".join(f"{r['teste']}={r['status']}" for r in gls) or "nao executado"), ""]
    lines += ["| run | SDC | clock | folga setup (pior corner) | Fmax est. | DRC | LVS | antena | slew (limite) | cap | area std-cell | potencia |",
              "|---|---|---|---|---|---|---|---|---|---|---|---|"]
    for r in runs:
        lines.append(f"| {r['label']} | {r['sdc']} | {r['clock_period_ns']:.0f} ns ({r['clock_mhz']} MHz) | {r['setup_worst_slack_ns']:.2f} ns | "
                     f"{r['fmax_mhz_worst_corner']} MHz | {r['drc_klayout']} | {r['lvs_errors']} | {r['antenna_violations']} | "
                     f"{r['max_slew_violations']} ({r['slew_limit_ns']} ns) | {r['max_cap_violations']} | {r['stdcell_area_um2']:.0f} um2 | "
                     f"{r['power_total_w'] * 1000:.1f} mW |")
    lines += ["", "Rodadas com base.sdc usam clock ideal, sem derating/incerteza e o limite de slew da biblioteca (1,5 ns);",
              "signoff.sdc tem as restricoes completas do OpenLane (limite 0,75 ns, clock propagado, derating 5 %). Ver ADR-017."]
    (out / "RESUMO.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"reports/summary.json: ISA {isa_pass}/{len(matrix)}, {len(regression)} suites, {len(mutation)} mutantes, {len(runs)} runs fisicos")


if __name__ == "__main__":
    main()
