#!/usr/bin/env bash
# =============================================================================
# run_firmware_sim.sh - Builda o firmware, simula-o sobre soc_top (via
# tb/firmware/tb_firmware_smoke.sv) e salva waveform (VCD) + log como
# evidencia (docs/evidence/waveforms, docs/evidence/logs), conforme secao
# 7.5 do Plano Mestre.
# =============================================================================
set -euo pipefail
PROJDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$PROJDIR/scripts/build_firmware.sh"

# Offset (em palavras de 32b, relativo a DMEM_BASE) do simbolo result_addr -
# recalculado automaticamente a cada run para nao depender de valor fixo.
RESULT_ADDR_HEX=$(export MSYS_NO_PATHCONV=1; docker run --rm -v "C:/tmp/championchip-build:/work" -w /work championchip-dev:latest \
  bash -c "riscv64-unknown-elf-nm firmware/build/smoke_test.elf | awk '/ result_addr\$/ {print \$1}'")
RESULT_WORD_OFFSET=$(( (0x${RESULT_ADDR_HEX} - 0x10010000) / 4 ))
echo "result_addr=0x${RESULT_ADDR_HEX} -> RESULT_WORD_OFFSET=${RESULT_WORD_OFFSET}"

mkdir -p "$PROJDIR/docs/evidence/waveforms" "$PROJDIR/docs/evidence/logs"

export MSYS_NO_PATHCONV=1
docker run --rm -v "C:/tmp/championchip-build:/work" -w /work championchip-dev:latest bash -c "
mkdir -p /tmp/build
iverilog -g2012 -DRESULT_WORD_OFFSET=${RESULT_WORD_OFFSET} \
  -Irtl/core -Irtl/memory -Irtl/top -o /tmp/build/tb_firmware_smoke.vvp \
  tb/firmware/tb_firmware_smoke.sv rtl/core/*.sv rtl/memory/*.sv rtl/top/soc_top.sv
cd /work
vvp /tmp/build/tb_firmware_smoke.vvp | tee docs_evidence_fw.log
"
docker run --rm -v "C:/tmp/championchip-build:/work" -w /work championchip-dev:latest \
  bash -c "cat docs_evidence_fw.log" > /tmp/fw_run.log 2>/dev/null || true

# Copia log + hex + elf/dis como evidencia
cp "/c/tmp/championchip-build/docs_evidence_fw.log" "$PROJDIR/docs/evidence/logs/firmware_smoke.log" 2>/dev/null || true
mkdir -p "$PROJDIR/firmware/build"
cp "/c/tmp/championchip-build/firmware/build/smoke_test.hex" "$PROJDIR/firmware/build/" 2>/dev/null || true
cp "/c/tmp/championchip-build/firmware/build/smoke_test.dis" "$PROJDIR/firmware/build/" 2>/dev/null || true
cp "/c/tmp/championchip-build/firmware/build/smoke_test.map" "$PROJDIR/firmware/build/" 2>/dev/null || true

echo "Evidencias salvas em docs/evidence/logs/firmware_smoke.log e firmware/build/"
