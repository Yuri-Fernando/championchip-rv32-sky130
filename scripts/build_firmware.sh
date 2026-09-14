#!/usr/bin/env bash
# =============================================================================
# build_firmware.sh - Monta/linka o firmware de smoke-test com o toolchain
# RISC-V (riscv64-unknown-elf-gcc, multilib rv32) e converte para o formato
# hex ($readmemh) usado por rtl/memory/imem.sv. IMPORTANTE: -march=rv32im
# (SEM "c") para nao gerar instrucoes comprimidas de 16 bits, que este core
# nao decodifica (nao faz parte do escopo RV32I_Zmmul_Xicrc do guia).
# =============================================================================
set -euo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bash "$PROJDIR/scripts/sync_mirror.sh" to

export MSYS_NO_PATHCONV=1
docker run --rm -v "C:/tmp/championchip-build:/work" -w /work championchip-dev:latest bash -c '
set -e
mkdir -p firmware/build
cd firmware/build

riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
  -Wl,-T,../linker/link.ld -Wl,-Map=smoke_test.map -o smoke_test.elf \
  ../smoke/smoke_test.S

riscv64-unknown-elf-objdump -d smoke_test.elf > smoke_test.dis
riscv64-unknown-elf-nm -n smoke_test.elf > smoke_test.sym

# So a secao de codigo (IMEM) - .data/.bss ficam na DMEM, que ja inicializa
# em zero no modelo comportamental (rtl/memory/dmem.sv), suficiente para
# este firmware (nenhum dado .data pre-inicializado nao-zero e usado).
riscv64-unknown-elf-objcopy -O binary --only-section=.text --only-section=.rodata \
  smoke_test.elf smoke_test.bin
riscv64-unknown-elf-size smoke_test.elf

# Converte binario -> hex de 32 bits (little-endian) para $readmemh
python3 - << "PYEOF"
import struct
with open("smoke_test.bin","rb") as f:
    data = f.read()
pad = (-len(data)) % 4
data += b"\x00" * pad
with open("smoke_test.hex","w") as out:
    for i in range(0, len(data), 4):
        word = struct.unpack_from("<I", data, i)[0]
        out.write(f"{word:08x}\n")
print(f"palavras geradas: {len(data)//4}")
PYEOF
echo "OK: firmware/build/smoke_test.hex gerado"
'
