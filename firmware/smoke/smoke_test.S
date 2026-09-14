/* =============================================================================
 * smoke_test.S - Firmware de smoke-test bare-metal (autoral - firmware
 * oficial da competicao indisponivel, ver SPEC_GAPS.md SG-05).
 *
 * Estilo "riscv-tests": cada bloco calcula um resultado com uma instrucao
 * real e compara com o valor esperado (bne ... fail). Se todos os blocos
 * passarem, grava a assinatura PASS_SIG em RESULT_ADDR e executa EBREAK.
 * Qualquer falha grava FAIL_SIG (+ numero do teste em a1) e para.
 *
 * Cobertura: ADD/SUB, OR/AND/XOR, shifts, SLT/SLTU, LUI/AUIPC, load/store
 * (word/byte, sign/zero extend), branch, JAL/JALR, MUL/MULH (Zmmul).
 * Nao repete a cobertura exaustiva ja feita em tb/isa/* - aqui o objetivo e
 * provar a cadeia toolchain -> ELF -> hex -> simulacao -> execucao real.
 * ============================================================================= */

.section .text.start
.globl _start
_start:
    li   sp, 0x10011ff0
    li   s0, 0            /* numero do teste atual (para diagnostico em fail) */

test1_add_sub:
    addi s0, s0, 1
    li   t0, 12
    li   t1, 5
    add  t2, t0, t1
    li   t3, 17
    bne  t2, t3, fail
    sub  t2, t0, t1
    li   t3, 7
    bne  t2, t3, fail

test2_logic:
    addi s0, s0, 1
    li   t0, 0xF0
    li   t1, 0x0F
    or   t2, t0, t1
    li   t3, 0xFF
    bne  t2, t3, fail
    and  t2, t0, t1
    bne  t2, x0, fail
    xor  t2, t0, t0
    bne  t2, x0, fail

test3_shifts:
    addi s0, s0, 1
    li   t0, 1
    slli t2, t0, 4
    li   t3, 16
    bne  t2, t3, fail
    srli t2, t3, 4
    li   t4, 1
    bne  t2, t4, fail

test4_slt:
    addi s0, s0, 1
    li   t0, -1
    li   t1, 1
    slt  t2, t0, t1
    li   t3, 1
    bne  t2, t3, fail
    sltu t2, t0, t1
    bne  t2, x0, fail

test5_upper_imm:
    addi s0, s0, 1
    lui  t0, 0x12345
    li   t1, 0x12345000
    bne  t0, t1, fail
    auipc t2, 0
    beq  t2, x0, fail   /* auipc != 0 (estamos em IMEM, nunca endereco 0) */

test6_load_store:
    addi s0, s0, 1
    la   t1, data_buf
    li   t0, 0xDEADBEEF
    sw   t0, 0(t1)
    lw   t2, 0(t1)
    bne  t0, t2, fail
    li   t0, 0x7A
    sb   t0, 4(t1)
    lbu  t2, 4(t1)
    bne  t0, t2, fail
    li   t0, 0xABCD
    sh   t0, 8(t1)
    lhu  t2, 8(t1)
    bne  t0, t2, fail

test7_branch:
    addi s0, s0, 1
    li   t0, 5
    li   t1, 5
    beq  t0, t1, br_ok
    j    fail
br_ok:
    li   t1, 6
    bne  t0, t1, br_ok2
    j    fail
br_ok2:

test8_jal_jalr:
    addi s0, s0, 1
    jal  ra, subroutine
    j    after_sub
subroutine:
    li   a0, 42
    jalr x0, ra, 0
after_sub:
    li   t3, 42
    bne  a0, t3, fail

test9_zmmul:
    addi s0, s0, 1
    li   t0, 7
    li   t1, -3
    mul  t2, t0, t1
    li   t3, -21
    bne  t2, t3, fail
    mulh t2, t0, t1
    li   t3, -1
    bne  t2, t3, fail

    j pass

fail:
    la   t0, result_addr
    li   t1, 0xBAD00BAD
    sw   t1, 0(t0)
    sw   s0, 4(t0)   /* numero do teste que falhou, para diagnostico */
    ebreak

pass:
    la   t0, result_addr
    li   t1, 0x600DC0DE
    sw   t1, 0(t0)
    sw   s0, 4(t0)   /* numero total de blocos executados com sucesso */
    ebreak

.section .data
.align 4
data_buf:
    .space 32
    .align 4
result_addr:
    .word 0
    .word 0
