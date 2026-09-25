# firmware/official — ponto de entrada do firmware oficial da competição

Esta pasta está reservada para o **firmware de referência da ChampionCHIP**
(requisito R7 do guia: "waveform e logs provando execução até o final do
firmware oficial").

**Status:** o firmware oficial ainda não foi disponibilizado — ver
[`docs/governance/SPEC_GAPS.md`](../../docs/governance/SPEC_GAPS.md), item **SG-05**.

Enquanto isso, a cadeia completa (GCC RISC-V → ELF → hex → simulação → execução)
está comprovada com o firmware autoral em [`../smoke/`](../smoke/), que roda
com sucesso tanto sobre o RTL quanto sobre a netlist gate-level pós-layout.

## Como integrar quando o firmware chegar

1. Copiar os fontes para esta pasta.
2. Conferir o linker script oficial contra `firmware/linker/link.ld`
   (IMEM em `0x0040_0000`, DMEM em `0x1001_0000`).
3. Compilar com `-march=rv32im -mabi=ilp32` (sem `c`: o core não decodifica
   instruções comprimidas).
4. Adaptar `scripts/core/firmware.sh` para o novo ELF e o critério de término
   (assinatura em memória, `ecall`/`ebreak`, ou escrita em endereço de MMIO).
5. Rodar `bash scripts/run_firmware_sim.sh` e `bash scripts/run_gls.sh`.
