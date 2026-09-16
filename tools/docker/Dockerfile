# Ambiente de desenvolvimento/verificacao do ChampionCHIP RV32I_Zmmul_Xicrc
# Contem: Icarus Verilog, Verilator, toolchain RISC-V (newlib, rv32), Python3, GTKWave (headless libs)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    iverilog \
    verilator \
    yosys \
    gtkwave \
    python3 \
    python3-pip \
    python3-venv \
    python3-tk \
    docker.io \
    gcc-riscv64-unknown-elf \
    binutils-riscv64-unknown-elf \
    picolibc-riscv64-unknown-elf \
    git \
    make \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# OpenLane 2 (RTL-to-GDSII orchestrator) - orquestra containers de
# sintese/PnR/STA via o docker.sock do host (ver DECISIONS.md ADR-009/010).
RUN pip3 install --break-system-packages --no-cache-dir openlane

WORKDIR /work
