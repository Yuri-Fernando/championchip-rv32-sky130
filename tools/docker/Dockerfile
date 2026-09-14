# Ambiente de desenvolvimento/verificacao do ChampionCHIP RV32I_Zmmul_Xicrc
# Contem: Icarus Verilog, Verilator, toolchain RISC-V (newlib, rv32), Python3, GTKWave (headless libs)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    iverilog \
    verilator \
    gtkwave \
    python3 \
    python3-pip \
    python3-venv \
    gcc-riscv64-unknown-elf \
    binutils-riscv64-unknown-elf \
    picolibc-riscv64-unknown-elf \
    git \
    make \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
