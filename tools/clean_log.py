#!/usr/bin/env python3
"""
clean_log.py - Limpa logs de terminal do OpenLane: remove codigos ANSI e
hyperlinks OSC-8, e descarta as linhas de barra de progresso redesenhadas
(mantendo apenas a ultima de cada etapa). Reduz ~12 MB para dezenas de KB
sem perder avisos, erros ou a sequencia de etapas.

Uso: python tools/clean_log.py <log> [<log> ...]   (reescreve no lugar)
"""
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\]8;[^\x1b\x07]*(?:\x1b\\|\x07)")
PROGRESS = re.compile(r"^Classic - Stage \d+ - .*[━╺╸]")
ELAPSED = re.compile(r"\d+/\d+ \d+:\d{2}:\d{2}")  # "73/78 0:51:30" no fim da barra
# barra truncada pelo terminal quando o nome da etapa é longo: "Classic - Stage 36 - ... …"
TRUNCATED = re.compile(r"^(Classic - Stage \d+ - .*?)\s*…$")


def clean(text: str) -> str:
    out, last_stage = [], None
    for raw in text.replace("\r\n", "\n").split("\n"):
        for piece in raw.split("\r"):
            line = ANSI.sub("", piece).rstrip()
            if not line:
                continue
            t = TRUNCATED.match(line)
            if t:
                if t.group(1) != last_stage:
                    out.append(t.group(1))
                    last_stage = t.group(1)
                continue
            while PROGRESS.match(line):
                stage = re.split(r"[━╺╸]", line)[0].strip()
                if stage != last_stage:
                    out.append(stage)
                    last_stage = stage
                m = ELAPSED.search(line)
                line = line[m.end():].strip() if m else ""  # texto colado depois da barra
            if line:
                out.append(line)
    return "\n".join(out) + "\n"


for path in sys.argv[1:]:
    with open(path, encoding="utf-8", errors="replace") as f:
        data = f.read()
    cleaned = clean(data)
    with open(path, "w", encoding="utf-8") as f:
        f.write(cleaned)
    print(f"{path}: {len(data) // 1024} KB -> {len(cleaned) // 1024} KB")
