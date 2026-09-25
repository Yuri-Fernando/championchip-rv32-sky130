#!/usr/bin/env bash
# =============================================================================
# core/firmware.sh - Monta o firmware de smoke-test e (se BUILD_ONLY != 1) o
# simula sobre soc_top, gerando log + waveform VCD como evidencia.
# Roda DENTRO do ambiente (container championchip-dev ou nativo), cwd = raiz.
#
# -march=rv32im (SEM "c"): o core nao decodifica instrucoes comprimidas.
# =============================================================================
set -euo pipefail
mkdir -p firmware/build docs/evidence/logs docs/evidence/waveforms build/fw
cd firmware/build

riscv64-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles \
  -Wl,-T,../linker/link.ld -Wl,-Map=smoke_test.map -o smoke_test.elf \
  ../smoke/smoke_test.S
riscv64-unknown-elf-objdump -d smoke_test.elf > smoke_test.dis
riscv64-unknown-elf-nm -n smoke_test.elf > smoke_test.sym
# So .text/.rodata vao para a IMEM (a DMEM do modelo ja inicia zerada).
riscv64-unknown-elf-objcopy -O binary --only-section=.text --only-section=.rodata \
  smoke_test.elf smoke_test.bin
python3 - <<'PYEOF'
import struct
data = open("smoke_test.bin", "rb").read()
data += b"\x00" * ((-len(data)) % 4)
with open("smoke_test.hex", "w") as out:
    for k in range(0, len(data), 4):
        out.write(f"{struct.unpack_from('<I', data, k)[0]:08x}\n")
print(f"firmware: {len(data)//4} palavras de 32 bits")
PYEOF
cd ../..

[ "${BUILD_ONLY:-0}" = 1 ] && exit 0

# offset (em palavras, relativo a DMEM_BASE) do simbolo result_addr
RESULT_ADDR_HEX=$(awk '/ result_addr$/ {print $1}' firmware/build/smoke_test.sym)
RESULT_WORD_OFFSET=$(( (0x${RESULT_ADDR_HEX} - 0x10010000) / 4 ))

iverilog -g2012 -DRESULT_WORD_OFFSET="${RESULT_WORD_OFFSET}" \
  -Irtl/core -Irtl/memory -Irtl/top -o build/fw/tb_firmware_smoke.vvp \
  tb/firmware/tb_firmware_smoke.sv rtl/core/*.sv rtl/memory/*.sv rtl/top/soc_top.sv \
  2> build/fw/compile.log
vvp -n build/fw/tb_firmware_smoke.vvp +vcd | tee docs/evidence/logs/firmware_smoke.log
grep -q "=== tb_firmware_smoke: PASS" docs/evidence/logs/firmware_smoke.log
