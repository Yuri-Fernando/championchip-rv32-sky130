#!/usr/bin/env python3
"""
run_mutation.py - Teste de mutacao: mede se a verificacao randomizada
realmente detecta bugs. Cada mutante injeta UM bug realista no RTL (uma
troca de signed/unsigned, um sign-extend esquecido, etc.), roda os programas
aleatorios e verifica se algum diverge do modelo de referencia. O RTL
original e restaurado sempre (inclusive em erro).

Uso (dentro do ambiente com iverilog, apos gerar build/random/):
    python3 tools/mutation/run_mutation.py [--seeds 1 2 3 ...]
Saida: tabela no stdout + reports/mutation.csv
"""
from __future__ import annotations

import argparse
import csv
import os
import subprocess
import sys

MUTANTS = [
    ("ALU: SRA vira SRL", "rtl/core/alu.sv",
     "`ALU_SRA:   result_o = $signed($signed(a_i) >>> shamt);", "`ALU_SRA:   result_o = a_i >> shamt;"),
    ("ALU: SLT vira SLTU", "rtl/core/alu.sv",
     "`ALU_SLT:   result_o = {31'd0, ($signed(a_i) < $signed(b_i))};", "`ALU_SLT:   result_o = {31'd0, (a_i < b_i)};"),
    ("ALU: SUB vira ADD", "rtl/core/alu.sv",
     "`ALU_SUB:   result_o = a_i - b_i;", "`ALU_SUB:   result_o = a_i + b_i;"),
    ("MUL: MULHSU usa signed x signed", "rtl/core/mult_unit.sv",
     "`F3_MULHSU: result_o = product_su[63:32];", "`F3_MULHSU: result_o = product_ss[63:32];"),
    ("MUL: MULHU usa signed x signed", "rtl/core/mult_unit.sv",
     "`F3_MULHU:  result_o = product_uu[63:32];", "`F3_MULHU:  result_o = product_ss[63:32];"),
    ("LSU: LB sem sign-extend", "rtl/core/lsu.sv",
     "`F3_LB:  load_data_o = {{24{byte_sel[7]}}, byte_sel};", "`F3_LB:  load_data_o = {24'd0, byte_sel};"),
    ("LSU: LH sem sign-extend", "rtl/core/lsu.sv",
     "`F3_LH:  load_data_o = {{16{half_sel[15]}}, half_sel};", "`F3_LH:  load_data_o = {16'd0, half_sel};"),
    ("LSU: SH sempre na metade baixa", "rtl/core/lsu.sv",
     "bw_o        = addr_lsb_i[1] ? 4'b1100 : 4'b0011;", "bw_o        = 4'b0011;"),
    ("BRANCH: BLTU vira BLT", "rtl/core/branch_cmp.sv",
     "`F3_BLTU: taken_o = (rs1_i <  rs2_i);", "`F3_BLTU: taken_o = ($signed(rs1_i) < $signed(rs2_i));"),
    ("BRANCH: BGE vira BGT", "rtl/core/branch_cmp.sv",
     "`F3_BGE:  taken_o = ($signed(rs1_i) >= $signed(rs2_i));", "`F3_BGE:  taken_o = ($signed(rs1_i) > $signed(rs2_i));"),
    ("IMM: imediato B sem bit 11", "rtl/core/imm_gen.sv",
     "`IMM_B:  imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7],", "`IMM_B:  imm_o = {{19{instr_i[31]}}, instr_i[31], 1'b0,"),
    ("REGFILE: x0 gravavel", "rtl/core/regfile.sv",
     "assign rs1_rdata_o = (rs1_addr_i == 5'd0) ? 32'd0 : regs[rs1_addr_i];",
     "assign rs1_rdata_o = regs[rs1_addr_i == 5'd0 ? 5'd1 : rs1_addr_i];"),
    ("CORE: link do JAL = PC atual (sem +4)", "rtl/core/rv32_core.sv",
     "link_reg     <= pc_plus4;", "link_reg     <= pc_reg;"),
]

COMPILE = ["iverilog", "-g2012", "-Irtl/core", "-Irtl/memory", "-Irtl/top", "-o", "/tmp/mut.vvp",
           "tb/random/tb_random.sv"]


def sources() -> list[str]:
    out = []
    for d in ("rtl/core", "rtl/memory"):
        out += sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".sv"))
    return out + ["rtl/top/soc_top.sv"]


def run_seeds(seeds: list[int]) -> int:
    subprocess.run(COMPILE + sources(), check=True, capture_output=True)
    failing = 0
    for s in seeds:
        res = subprocess.run(["vvp", "-n", "/tmp/mut.vvp", f"+PROG=build/random/prog_{s}.hex",
                              f"+EXP=build/random/expected_{s}.hex"], capture_output=True, text=True)
        if "PASS" not in res.stdout:
            failing += 1
    return failing


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, nargs="+", default=list(range(1, 21)))
    args = ap.parse_args()

    baseline = run_seeds(args.seeds)
    if baseline:
        print(f"ERRO: o RTL original ja falha em {baseline} seeds - corrija antes de medir mutacao.")
        return 1

    rows, killed = [], 0
    for name, path, old, new in MUTANTS:
        with open(path, encoding="utf-8") as f:
            original = f.read()
        if original.count(old) != 1:
            print(f"ERRO: padrao do mutante '{name}' nao encontrado exatamente 1x em {path}")
            return 1
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(original.replace(old, new))
            detected_in = run_seeds(args.seeds)
        finally:
            with open(path, "w", encoding="utf-8") as f:
                f.write(original)
        status = "MORTO" if detected_in else "SOBREVIVEU"
        killed += bool(detected_in)
        rows.append((name, path, detected_in, len(args.seeds), status))
        print(f"{status:10s} {name:40s} detectado em {detected_in:2d}/{len(args.seeds)} programas")

    score = 100.0 * killed / len(MUTANTS)
    print(f"\nMutation score: {killed}/{len(MUTANTS)} mutantes mortos ({score:.0f}%)")
    os.makedirs("reports", exist_ok=True)
    with open("reports/mutation.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mutante", "arquivo", "programas_que_detectaram", "programas_total", "status"])
        w.writerows(rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
