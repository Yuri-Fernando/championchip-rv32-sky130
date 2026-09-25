#!/usr/bin/env python3
"""
rv32_iss.py - Modelo de referencia (Instruction Set Simulator) RV32I + Zmmul.

Escrito a partir da especificacao RISC-V (e NAO a partir do RTL), para servir
de oraculo independente nos testes diferenciais (secao 7.4 do Plano Mestre,
mitigacao do risco R-04 "signedness em MUL/SLT/branch").

Escopo: as 44 instrucoes fechadas (RV32I 40 + Zmmul 4). Xicrc NAO e modelado
(semantica BLOCKED-XICRC, ver docs/governance/SPEC_GAPS.md SG-01) - encontrar
uma instrucao Xicrc levanta erro.

Sem dependencias externas (so stdlib), para rodar igual no container, no CI e
no host.
"""
from __future__ import annotations

import sys
from collections import Counter

MASK32 = 0xFFFF_FFFF
IMEM_BASE = 0x0040_0000
DMEM_BASE = 0x1001_0000
DMEM_SIZE = 8 * 1024


def sx(value: int, bits: int) -> int:
    """Sign-extend `value` (de `bits` bits) para int Python."""
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def s32(v: int) -> int:
    return sx(v, 32)


class IssError(Exception):
    pass


class RV32ISS:
    def __init__(self, program_words: list[int], max_steps: int = 200_000):
        self.imem = list(program_words)
        self.dmem = bytearray(DMEM_SIZE)
        self.x = [0] * 32
        self.pc = IMEM_BASE
        self.max_steps = max_steps
        self.steps = 0
        self.halted = False
        self.histogram: Counter[str] = Counter()
        # faixa de PCs [lo, hi) contabilizada no histograma (None = tudo);
        # o gerador aleatorio usa isso para medir so o corpo aleatorio,
        # sem o prologo/epilogo fixos
        self.count_range: tuple[int, int] | None = None

    # ---- memoria de dados -----------------------------------------------
    def _dmem_off(self, addr: int, size: int) -> int:
        off = addr - DMEM_BASE
        if off < 0 or off + size > DMEM_SIZE:
            raise IssError(f"acesso fora da DMEM: 0x{addr:08x}")
        if off % size:
            raise IssError(f"acesso desalinhado ({size}B) em 0x{addr:08x}")
        return off

    def load(self, addr: int, size: int, signed: bool) -> int:
        off = self._dmem_off(addr, size)
        val = int.from_bytes(self.dmem[off:off + size], "little")
        return (sx(val, 8 * size) & MASK32) if signed else val

    def store(self, addr: int, size: int, value: int) -> None:
        off = self._dmem_off(addr, size)
        self.dmem[off:off + size] = (value & ((1 << (8 * size)) - 1)).to_bytes(size, "little")

    def dmem_words(self, n_words: int) -> list[int]:
        return [int.from_bytes(self.dmem[4 * i:4 * i + 4], "little") for i in range(n_words)]

    # ---- execucao ----------------------------------------------------------
    def wr(self, rd: int, value: int) -> None:
        if rd != 0:
            self.x[rd] = value & MASK32

    def fetch(self) -> int:
        idx = (self.pc - IMEM_BASE) >> 2
        if self.pc & 3 or not 0 <= idx < len(self.imem):
            raise IssError(f"fetch fora do programa: pc=0x{self.pc:08x}")
        return self.imem[idx]

    def run(self) -> "RV32ISS":
        while not self.halted:
            if self.steps >= self.max_steps:
                raise IssError("limite de passos excedido (loop?)")
            self.step()
        return self

    def step(self) -> None:  # noqa: C901 - decode plano e intencional (espelha a spec)
        ins = self.fetch()
        self.steps += 1
        op = ins & 0x7F
        rd = (ins >> 7) & 0x1F
        f3 = (ins >> 12) & 0x7
        rs1 = (ins >> 15) & 0x1F
        rs2 = (ins >> 20) & 0x1F
        f7 = ins >> 25
        a, b = self.x[rs1], self.x[rs2]
        imm_i = sx(ins >> 20, 12)
        imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 0x1F), 12)
        imm_b = sx((((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11)
                   | (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
        imm_u = ins & 0xFFFF_F000
        imm_j = sx((((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12)
                   | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
        next_pc = (self.pc + 4) & MASK32

        if op == 0x33 and f7 in (0x00, 0x20):  # ALU reg-reg
            sh = b & 0x1F
            name, res = {
                (0, 0x00): ("ADD", a + b), (0, 0x20): ("SUB", a - b),
                (1, 0x00): ("SLL", a << sh),
                (2, 0x00): ("SLT", int(s32(a) < s32(b))),
                (3, 0x00): ("SLTU", int(a < b)),
                (4, 0x00): ("XOR", a ^ b),
                (5, 0x00): ("SRL", a >> sh), (5, 0x20): ("SRA", s32(a) >> sh),
                (6, 0x00): ("OR", a | b), (7, 0x00): ("AND", a & b),
            }.get((f3, f7), (None, None))
            if name is None:
                raise IssError(f"R-type invalida 0x{ins:08x}")
            self.wr(rd, res)
        elif op == 0x33 and f7 == 0x01:  # Zmmul
            sa, sb = s32(a), s32(b)
            name, res = [("MUL", sa * sb), ("MULH", (sa * sb) >> 32),
                         ("MULHSU", (sa * b) >> 32), ("MULHU", (a * b) >> 32)][f3] if f3 < 4 else (None, None)
            if name is None:
                raise IssError(f"Zmmul invalida 0x{ins:08x}")
            self.wr(rd, res)
        elif op == 0x33 and f7 == 0x40:
            raise IssError("Xicrc nao modelado (BLOCKED-XICRC)")
        elif op == 0x13:  # ALU imm
            sh = rs2  # shamt = imm[4:0]
            if f3 == 1:
                name, res = "SLLI", a << sh
            elif f3 == 5:
                name, res = ("SRAI", s32(a) >> sh) if f7 == 0x20 else ("SRLI", a >> sh)
            else:
                name, res = {0: ("ADDI", a + imm_i), 2: ("SLTI", int(s32(a) < imm_i)),
                             3: ("SLTIU", int(a < (imm_i & MASK32))), 4: ("XORI", a ^ (imm_i & MASK32)),
                             6: ("ORI", a | (imm_i & MASK32)), 7: ("ANDI", a & (imm_i & MASK32))}[f3]
            self.wr(rd, res)
        elif op == 0x03:  # loads
            addr = (a + imm_i) & MASK32
            name, size, signed = {0: ("LB", 1, True), 1: ("LH", 2, True), 2: ("LW", 4, False),
                                  4: ("LBU", 1, False), 5: ("LHU", 2, False)}[f3]
            self.wr(rd, self.load(addr, size, signed))
        elif op == 0x23:  # stores
            addr = (a + imm_s) & MASK32
            name, size = {0: ("SB", 1), 1: ("SH", 2), 2: ("SW", 4)}[f3]
            self.store(addr, size, b)
        elif op == 0x63:  # branches
            name, taken = {0: ("BEQ", a == b), 1: ("BNE", a != b),
                           4: ("BLT", s32(a) < s32(b)), 5: ("BGE", s32(a) >= s32(b)),
                           6: ("BLTU", a < b), 7: ("BGEU", a >= b)}[f3]
            if taken:
                next_pc = (self.pc + imm_b) & MASK32
        elif op == 0x6F:
            name = "JAL"
            self.wr(rd, next_pc)
            next_pc = (self.pc + imm_j) & MASK32
        elif op == 0x67:
            name = "JALR"
            target = (a + imm_i) & MASK32 & ~1
            self.wr(rd, next_pc)
            next_pc = target
        elif op == 0x37:
            name = "LUI"
            self.wr(rd, imm_u)
        elif op == 0x17:
            name = "AUIPC"
            self.wr(rd, self.pc + imm_u)
        elif op == 0x0F:
            name = "FENCE"
        elif op == 0x73:
            name = "EBREAK" if (ins >> 20) == 1 else "ECALL"
            self.halted = True
        else:
            raise IssError(f"opcode desconhecido 0x{ins:08x} em pc=0x{self.pc:08x}")

        if self.count_range is None or self.count_range[0] <= self.pc < self.count_range[1]:
            self.histogram[name] += 1
        self.pc = next_pc


def load_hex(path: str) -> list[int]:
    with open(path, encoding="ascii") as f:
        return [int(line.strip(), 16) for line in f if line.strip() and not line.startswith("//")]


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: rv32_iss.py programa.hex")
        sys.exit(2)
    iss = RV32ISS(load_hex(sys.argv[1])).run()
    print(f"halt apos {iss.steps} instrucoes, pc=0x{iss.pc:08x}")
    for i in range(1, 32):
        print(f"x{i:<2} = 0x{iss.x[i]:08x}")
