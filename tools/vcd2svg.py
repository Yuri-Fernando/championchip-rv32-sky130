#!/usr/bin/env python3
"""
vcd2svg.py - Renderiza uma janela de um VCD como waveform em SVG (sem
dependencias externas). Usado para gerar as figuras de evidencia do firmware
(docs/evidence/waveforms/*.svg) consumidas pelo relatorio, notebooks e
dashboard. Traços usam `currentColor`, entao o SVG herda a cor do texto da
pagina onde for embutido (funciona em tema claro e escuro).

Uso:
  python3 tools/vcd2svg.py <arquivo.vcd> <saida.svg> --start 0 --cycles 40 \
      --signals clk_i state pc_reg ir_reg mem_we_o halt_o
  --end-at-last   ancora a janela nos ultimos N ciclos da simulacao
"""
from __future__ import annotations

import argparse
from xml.sax.saxutils import escape

STATE_NAMES = ["FETCH", "DECODE", "EX_ALU", "EX_BR", "EX_JMP", "MEM_ADDR", "MEM_RD", "MEM_WAIT",
               "MEM_WR", "EX_MUL", "EX_CRC", "SYSTEM", "WB_ALU", "WB_MEM", "WB_MUL", "WB_CRC"]


def parse_vcd(path: str):
    """Retorna ({nome: (largura, [(t, valor_str)])}, t_final)."""
    idmap, sigs, t, header = {}, {}, 0, True
    with open(path, encoding="ascii", errors="replace") as f:
        for line in f:
            tok = line.split()
            if not tok:
                continue
            if header:
                if tok[0] == "$var":
                    width, code, name = int(tok[2]), tok[3], tok[4]
                    idmap.setdefault(code, []).append(name)
                    sigs.setdefault(name, (width, []))
                elif tok[0] == "$enddefinitions":
                    header = False
                continue
            c = tok[0][0]
            if c == "#":
                t = int(tok[0][1:])
            elif c in "01xzXZ" and len(tok) == 1:
                for n in idmap.get(tok[0][1:], []):
                    sigs[n][1].append((t, tok[0][0]))
            elif c in "bB" and len(tok) == 2:
                for n in idmap.get(tok[1], []):
                    sigs[n][1].append((t, tok[0][1:]))
    return sigs, t


def value_at(changes, t):
    v = "x"
    for tc, val in changes:
        if tc > t:
            break
        v = val
    return v


def fmt(name: str, width: int, raw: str) -> str:
    if any(ch in raw for ch in "xXzZ"):
        return "x"
    n = int(raw, 2)
    if name in ("state", "state_dbg_o") and n < len(STATE_NAMES):
        return STATE_NAMES[n]
    return f"{n:0{max(1, (width + 3) // 4)}x}" if width > 1 else str(n)


def render(sigs, t_end, signals, start, cycles, period, title) -> str:
    label_w, lane_h, gap, cyc_w = 96, 22, 8, 44
    t0, t1 = start, start + cycles * period
    width = label_w + cycles * cyc_w + 10
    height = 34 + len(signals) * (lane_h + gap) + 10
    x = lambda t: label_w + (t - t0) / period * cyc_w
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
           f'width="{width}" height="{height}" font-family="ui-monospace,Consolas,monospace" font-size="10" '
           f'role="img" aria-label="{escape(title)}">',
           f'<text x="4" y="14" font-size="12" font-weight="600" fill="currentColor">{escape(title)}</text>']
    for c in range(cycles + 1):  # grade de ciclos
        gx = label_w + c * cyc_w
        out.append(f'<line x1="{gx}" y1="24" x2="{gx}" y2="{height - 6}" stroke="currentColor" stroke-opacity="0.08"/>')
    for i, name in enumerate(signals):
        if name not in sigs:
            continue
        width_bits, ch = sigs[name]
        y0 = 30 + i * (lane_h + gap)
        yh, yl, ym = y0 + 2, y0 + lane_h - 2, y0 + lane_h / 2
        out.append(f'<text x="4" y="{ym + 3}" fill="currentColor" opacity="0.8">{escape(name)}</text>')
        pts = [(t0, value_at(ch, t0))] + [(t, v) for t, v in ch if t0 < t < t1]
        segs = [(pts[k][0], pts[k + 1][0] if k + 1 < len(pts) else t1, pts[k][1]) for k in range(len(pts))]
        if width_bits == 1:
            path = []
            for ta, tb, v in segs:
                y = yh if v == "1" else yl
                path.append(f"{'M' if not path else 'L'}{x(ta):.1f},{y} L{x(tb):.1f},{y}")
            out.append(f'<path d="{" ".join(path)}" fill="none" stroke="currentColor" stroke-width="1.4"/>')
        else:
            for ta, tb, v in segs:
                xa, xb = x(ta), x(tb)
                s = 3 if xb - xa > 8 else 0
                out.append(f'<path d="M{xa},{ym} L{xa + s},{yh} L{xb - s},{yh} L{xb},{ym} L{xb - s},{yl} '
                           f'L{xa + s},{yl} Z" fill="#3a7bd5" fill-opacity="0.14" stroke="currentColor" stroke-width="1"/>')
                label = fmt(name, width_bits, v)
                if (xb - xa) > len(label) * 6 + 6:
                    out.append(f'<text x="{(xa + xb) / 2:.1f}" y="{ym + 3.5}" text-anchor="middle" '
                               f'fill="currentColor">{escape(label)}</text>')
    out.append("</svg>")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("vcd")
    ap.add_argument("svg")
    ap.add_argument("--signals", nargs="+", required=True)
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--cycles", type=int, default=40)
    ap.add_argument("--period", type=int, default=10)
    ap.add_argument("--end-at-last", action="store_true")
    ap.add_argument("--title", default="")
    a = ap.parse_args()
    sigs, t_end = parse_vcd(a.vcd)
    start = max(0, t_end - a.cycles * a.period) if a.end_at_last else a.start
    with open(a.svg, "w", encoding="utf-8") as f:
        f.write(render(sigs, t_end, a.signals, start, a.cycles, a.period, a.title))
    print(f"{a.svg}: {len(a.signals)} sinais, ciclos {start // a.period}..{start // a.period + a.cycles}")


if __name__ == "__main__":
    main()
