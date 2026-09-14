/* =============================================================================
 * link.ld - Linker script bare-metal para o ChampionCHIP RV32I_Zmmul_Xicrc.
 * Mapa de memoria conforme rtl/core/rv32_defs.vh (secao 5.6 do Plano Mestre).
 * SG-05 (SPEC_GAPS.md): sem firmware/linker oficial da competicao ainda -
 * este script e autoral, usado apenas para o firmware de smoke-test.
 * ============================================================================= */
ENTRY(_start)

MEMORY
{
    IMEM (rx) : ORIGIN = 0x00400000, LENGTH = 16K
    DMEM (rw) : ORIGIN = 0x10010000, LENGTH = 8K
}

SECTIONS
{
    .text : {
        *(.text.start)
        *(.text*)
    } > IMEM

    .rodata : {
        *(.rodata*)
    } > IMEM

    .data : {
        *(.data*)
    } > DMEM

    .bss (NOLOAD) : {
        *(.bss*)
        *(COMMON)
    } > DMEM

    /DISCARD/ : { *(.riscv.attributes) *(.comment) *(.eh_frame*) }
}
