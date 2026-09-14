// =============================================================================
// rv32_encode.vh - Funcoes de encoding RV32I/Zmmul/Xicrc para montar
// instrucoes diretamente nos testbenches de ISA (testes dirigidos por
// instrucao, secao 7.3 do Plano Mestre). Reduz risco de erro manual de bits
// (ja detectado e corrigido em tb_imm_gen.sv durante o desenvolvimento).
// =============================================================================
`ifndef RV32_ENCODE_VH
`define RV32_ENCODE_VH

function automatic [31:0] enc_r(input [6:0] opcode, input [2:0] f3, input [6:0] f7,
                                  input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
    enc_r = {f7, rs2, rs1, f3, rd, opcode};
endfunction

function automatic [31:0] enc_i(input [6:0] opcode, input [2:0] f3,
                                  input [4:0] rd, input [4:0] rs1, input [11:0] imm12);
    enc_i = {imm12, rs1, f3, rd, opcode};
endfunction

// Para SLLI/SRLI/SRAI: imm12[11:5]=funct7, imm12[4:0]=shamt
function automatic [31:0] enc_ishift(input [6:0] opcode, input [2:0] f3, input [6:0] f7,
                                       input [4:0] rd, input [4:0] rs1, input [4:0] shamt);
    enc_ishift = {f7, shamt, rs1, f3, rd, opcode};
endfunction

function automatic [31:0] enc_s(input [6:0] opcode, input [2:0] f3,
                                  input [4:0] rs1, input [4:0] rs2, input [11:0] imm12);
    enc_s = {imm12[11:5], rs2, rs1, f3, imm12[4:0], opcode};
endfunction

function automatic [31:0] enc_b(input [6:0] opcode, input [2:0] f3,
                                  input [4:0] rs1, input [4:0] rs2, input signed [12:0] imm13);
    enc_b = {imm13[12], imm13[10:5], rs2, rs1, f3, imm13[4:1], imm13[11], opcode};
endfunction

function automatic [31:0] enc_u(input [6:0] opcode, input [4:0] rd, input [31:12] imm20);
    enc_u = {imm20, rd, opcode};
endfunction

function automatic [31:0] enc_j(input [6:0] opcode, input [4:0] rd, input signed [20:0] imm21);
    enc_j = {imm21[20], imm21[10:1], imm21[11], imm21[19:12], rd, opcode};
endfunction

`endif
