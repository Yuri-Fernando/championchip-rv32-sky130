"""
_common.py - Utilitarios compartilhados pelos notebooks (sem logica de
projeto: os notebooks apenas chamam os mesmos scripts versionados em scripts/
e leem os artefatos gerados, para nunca divergir do que o CI e o terminal fazem).
"""
from __future__ import annotations

import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Paleta validada (colorblind-safe) usada em todos os graficos dos notebooks
SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]
INK, INK2, GRID = "#0b0b0b", "#52514e", "#e1e0d9"


def bash_exe() -> str:
    """bash do sistema (Linux/macOS) ou do Git for Windows."""
    if platform.system() != "Windows":
        return "bash"
    for cand in (r"C:\Program Files\Git\bin\bash.exe", r"C:\Program Files (x86)\Git\bin\bash.exe"):
        if os.path.exists(cand):
            return cand
    return shutil.which("bash") or "bash"


def run(cmd: str, timeout: int = 3600, tail: int | None = 40) -> int:
    """Roda `cmd` (ex.: 'bash scripts/run_regression.sh') na raiz do projeto
    e mostra as ultimas `tail` linhas da saida."""
    proc = subprocess.run([bash_exe(), "-lc", f'cd "{ROOT.as_posix()}" && {cmd}'],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    lines = (proc.stdout + proc.stderr).splitlines()
    print("\n".join(lines[-tail:] if tail else lines))
    print(f"[exit code {proc.returncode}]")
    return proc.returncode


def py(script: str, *args: str) -> None:
    """Roda um script Python do repositorio com o mesmo interpretador do kernel."""
    out = subprocess.run([sys.executable, str(ROOT / script), *args], capture_output=True, text=True,
                         encoding="utf-8", errors="replace", cwd=ROOT)
    print(out.stdout + out.stderr)


def summary(rebuild: bool = True) -> dict:
    """Carrega reports/summary.json (regenerado a partir dos artefatos reais)."""
    if rebuild:
        py("tools/build_reports.py")
    return json.loads((ROOT / "reports/summary.json").read_text(encoding="utf-8"))


def style(ax, title: str = "", xlabel: str = "", ylabel: str = "") -> None:
    """Estilo recessivo: grade fina, eixos discretos, texto em tinta neutra."""
    ax.set_title(title, loc="left", fontsize=12, color=INK, fontweight="bold")
    ax.set_xlabel(xlabel, color=INK2)
    ax.set_ylabel(ylabel, color=INK2)
    ax.tick_params(colors=INK2, labelsize=9)
    for side in ("top", "right"):
        ax.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        ax.spines[side].set_color("#c3c2b7")
    ax.grid(axis="both", color=GRID, linewidth=0.6)
    ax.set_axisbelow(True)
