#!/usr/bin/env python3
"""
gen_random_program.py - Gerador de programas aleatorios para teste diferencial
(RTL/gate-level vs modelo de referencia rv32_iss.py).

Estrutura de cada programa:
  1. prologo: x31 = base da DMEM; x1..x30 com valores aleatorios (LUI+ADDI),
     incluindo casos extremos (0, -1, INT_MIN, INT_MAX, 0xFFFFFFFF...)
  2. N instrucoes aleatorias validas: ALU reg/imm, Zmmul, LUI/AUIPC,
     loads/stores alinhados na janela [0, 256) da DMEM, branches e JAL
     SEMPRE para frente (o programa sempre termina; sem loops)
  3. epilogo "assinatura": SW x1..x30 em DMEM[0x100 + 4*i], depois EBREAK

A comparacao e feita sobre a DMEM (janela de dados + assinatura), e NAO sobre
o regfile interno - por isso o mesmo teste roda contra o RTL e contra a
netlist gate-level pos-layout (onde nao existe hierarquia de registradores).

Saidas (em --outdir): prog_<seed>.hex, expected_<seed>.hex (96 palavras),
e um histograma de cobertura por instrucao (coverage_<seed>.csv).
"""
from __future__ import annotations

import argparse
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rv32_iss import IMEM_BASE, MASK32, RV32ISS  # noqa: E402

SIG_WORDS = 96  # 64 palavras de dados (0x000-0x0FF) + 32 de assinatura (0x100-0x17F)

# ---- encoders (mesmo layout de tb/isa/rv32_encode.vh) ----------------------
def r(op, f3, f7, rd, rs1, rs2): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def i(op, f3, rd, rs1, imm): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def s(op, f3, rs1, rs2, imm):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def b(f3, rs1, rs2, off):
    off &= 0x1FFF
    return (((off >> 12) & 1) << 31) | (((off >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) \
        | (f3 << 12) | (((off >> 1) & 0xF) << 8) | (((off >> 11) & 1) << 7) | 0x63
def u(op, rd, imm20): return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op
def j(rd, off):
    off &= 0x1FFFFF
    return (((off >> 20) & 1) << 31) | (((off >> 1) & 0x3FF) << 21) | (((off >> 11) & 1) << 20) \
        | (((off >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F

EBREAK = 0x00100073
BASE = 31  # x31 = ponteiro para DMEM, nunca sobrescrito
EXTREMES = [0, 1, 0xFFFFFFFF, 0x80000000, 0x7FFFFFFF, 0xFFFF, 0x8000, 0x80, 0xAAAAAAAA]

R_OPS = [(0, 0x00), (0, 0x20), (1, 0x00), (2, 0x00), (3, 0x00), (4, 0x00), (5, 0x00), (5, 0x20), (6, 0x00), (7, 0x00)]
I_OPS = [0, 2, 3, 4, 6, 7]


def li(rd: int, value: int) -> list[int]:
    """LUI+ADDI que materializa um valor de 32 bits arbitrario."""
    value &= MASK32
    lo = value & 0xFFF
    hi = (value + (0x800 if lo & 0x800 else 0)) >> 12
    return [u(0x37, rd, hi), i(0x13, 0, rd, rd, lo)]


LOOP_CNT = 30  # contador dos lacos de contagem regressiva (nao e escrito dentro do laco)


def simple_op(rng: random.Random, rd_pool: list[int]) -> tuple[str, int]:
    """Uma instrucao sem controle de fluxo (ALU, Zmmul, upper, load, store)."""
    src = lambda: rng.randint(0, 31)
    kind = rng.choices(["alu_r", "alu_i", "shift_i", "mul", "upper", "load", "store"],
                       weights=[20, 15, 6, 8, 5, 12, 12])[0]
    rd = rng.choice(rd_pool)
    if kind == "alu_r":
        f3, f7 = rng.choice(R_OPS)
        return kind, r(0x33, f3, f7, rd, src(), src())
    if kind == "alu_i":
        return kind, i(0x13, rng.choice(I_OPS), rd, src(), rng.randint(-2048, 2047))
    if kind == "shift_i":
        f3, f7 = rng.choice([(1, 0x00), (5, 0x00), (5, 0x20)])
        return kind, r(0x13, f3, f7, rd, src(), rng.randint(0, 31))
    if kind == "mul":
        return kind, r(0x33, rng.randint(0, 3), 0x01, rd, src(), src())
    if kind == "upper":
        return kind, u(rng.choice([0x37, 0x17]), rd, rng.getrandbits(20))
    if kind == "load":
        f3, size = rng.choice([(0, 1), (1, 2), (2, 4), (4, 1), (5, 2)])
        return kind, i(0x03, f3, rd, BASE, rng.randrange(0, 256, size))
    f3, size = rng.choice([(0, 1), (1, 2), (2, 4)])
    return kind, s(0x23, f3, BASE, src(), rng.randrange(0, 256, size))


def gen_items(rng: random.Random, n: int) -> list[dict]:
    """Corpo do programa como lista de 'itens'. Saltos para frente sempre
    caem no INICIO de um item (nunca no meio de um laco), o que garante
    terminacao. Lacos usam branch para TRAS (offset negativo), exercitando
    os bits altos do imediato B - lacuna encontrada pelo teste de mutacao."""
    rd_pool = list(range(1, 31)) + [0]  # inclui x0 (testa invariante x0==0)
    body_pool = [r_ for r_ in rd_pool if r_ != LOOP_CNT]
    items: list[dict] = []
    while sum(it["len"] for it in items) < n:
        kind = rng.choices(["simple", "load_obs", "branch", "jal", "loop"], weights=[72, 6, 14, 4, 4])[0]
        if kind == "simple":
            _, w = simple_op(rng, rd_pool)
            items.append({"kind": "simple", "words": [w], "len": 1})
        elif kind == "load_obs":
            # load seguido de SW do proprio resultado: torna observavel o
            # sign/zero-extend (lacuna do LH encontrada pelo teste de mutacao)
            f3, size = rng.choice([(0, 1), (1, 2), (4, 1), (5, 2)])
            rd = rng.randint(1, 29)
            words = [i(0x03, f3, rd, BASE, rng.randrange(0, 256, size)),
                     s(0x23, 2, BASE, rd, rng.randrange(0, 256, 4))]
            items.append({"kind": "load_obs", "words": words, "len": 2})
        elif kind == "branch":
            items.append({"kind": "branch", "f3": rng.choice([0, 1, 4, 5, 6, 7]),
                          "rs1": rng.randint(0, 31), "rs2": rng.randint(0, 31),
                          "skip": rng.randint(1, 6), "len": 1})
        elif kind == "jal":
            items.append({"kind": "jal", "rd": rng.choice(rd_pool), "skip": rng.randint(1, 6), "len": 1})
        else:
            iters, m = rng.randint(1, 4), rng.randint(1, 6)
            body = [simple_op(rng, body_pool)[1] for _ in range(m)]
            words = [i(0x13, 0, LOOP_CNT, 0, iters)]            # ADDI x30, x0, iters
            words += body                                        # corpo
            words.append(i(0x13, 0, LOOP_CNT, LOOP_CNT, -1))     # ADDI x30, x30, -1
            words.append(b(1, LOOP_CNT, 0, -4 * (m + 1)))        # BNE x30, x0, inicio_do_corpo
            items.append({"kind": "loop", "words": words, "len": len(words)})
    return items


def build_program(seed: int, n: int) -> tuple[list[int], tuple[int, int]]:
    rng = random.Random(seed)
    prog: list[int] = []
    prog += li(BASE, 0x1001_0000)
    for reg in range(1, 31):
        val = rng.choice(EXTREMES) if rng.random() < 0.3 else rng.getrandbits(32)
        prog += li(reg, val)
    # Preenche a janela de dados (64 palavras) com valores aleatorios: sem
    # isso quase todo load lia zero e o sign-extend de LH/LB nunca era
    # exercitado (lacuna revelada pelo teste de mutacao - ver HISTORICO.md).
    for word in range(64):
        prog.append(s(0x23, 2, BASE, rng.randint(1, 30), 4 * word))

    items = gen_items(rng, n)
    body_lo = len(prog)
    start, pos = [], len(prog)
    for it in items:
        start.append(pos)
        pos += it["len"]
    start.append(pos)  # "item" final = inicio do epilogo

    for idx, it in enumerate(items):
        if it["kind"] in ("branch", "jal"):
            target = min(idx + it["skip"] + 1, len(items))  # sempre inicio de item
            off = 4 * (start[target] - start[idx])
            if it["kind"] == "branch":
                prog.append(b(it["f3"], it["rs1"], it["rs2"], off))
            else:
                prog.append(j(it["rd"], off))
        else:
            prog += it["words"]
    assert len(prog) == start[-1]

    for reg in range(1, 31):  # epilogo: assinatura
        prog.append(s(0x23, 2, BASE, reg, 0x100 + 4 * (reg - 1)))
    prog.append(EBREAK)
    body = (IMEM_BASE + 4 * body_lo, IMEM_BASE + 4 * start[-1])  # faixa de PCs do corpo aleatorio
    return prog, body


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, nargs="+", default=list(range(1, 21)))
    ap.add_argument("--n", type=int, default=200, help="instrucoes aleatorias por programa")
    ap.add_argument("--outdir", default="build/random")
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    total = {}
    for seed in args.seeds:
        prog, body = build_program(seed, args.n)
        iss = RV32ISS(prog)
        iss.count_range = body
        iss.run()
        expected = iss.dmem_words(SIG_WORDS)
        with open(os.path.join(args.outdir, f"prog_{seed}.hex"), "w") as f:
            f.writelines(f"{w:08x}\n" for w in prog)
        with open(os.path.join(args.outdir, f"expected_{seed}.hex"), "w") as f:
            f.writelines(f"{w:08x}\n" for w in expected)
        for k, v in iss.histogram.items():
            total[k] = total.get(k, 0) + v
        print(f"seed {seed:3d}: {len(prog):4d} palavras, {iss.steps:4d} instrucoes executadas no ISS")

    with open(os.path.join(args.outdir, "coverage.csv"), "w") as f:
        f.write("instrucao,execucoes\n")
        for k in sorted(total, key=lambda k: -total[k]):
            f.write(f"{k},{total[k]}\n")
    print(f"cobertura do corpo aleatorio: {len(total)} instrucoes distintas, {sum(total.values())} execucoes")


if __name__ == "__main__":
    main()
