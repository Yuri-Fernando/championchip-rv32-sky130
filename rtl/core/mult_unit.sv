// =============================================================================
// mult_unit.sv - Unidade de multiplicacao Zmmul (MUL/MULH/MULHSU/MULHU).
// Zmmul e o subconjunto de multiplicacao da extensao M (mesmos encodings),
// confirmado pela especificacao oficial RISC-V (secao 15 do plano mestre).
// Produto de 64 bits formado a partir de operandos estendidos para reduzir
// risco de signedness incorreto (regra R-04 do registro de riscos).
// =============================================================================
`include "rv32_defs.vh"

module mult_unit (
    input  logic [31:0] a_i,       // rs1
    input  logic [31:0] b_i,       // rs2
    input  logic [2:0]  funct3_i,
    output logic [31:0] result_o
);

    logic signed [64:0] a_ext_signed;
    logic signed [64:0] b_ext_signed;
    logic signed [64:0] a_ext_unsigned; // usa bit extra p/ tratar operando unsigned em contexto signed
    logic signed [64:0] b_ext_unsigned;
    logic signed [64:0] product_ss; // signed x signed
    logic signed [64:0] product_su; // signed x unsigned (MULHSU)
    logic signed [64:0] product_uu; // unsigned x unsigned

    always_comb begin
        a_ext_signed   = {{33{a_i[31]}}, a_i};
        b_ext_signed   = {{33{b_i[31]}}, b_i};
        a_ext_unsigned = {33'd0, a_i};
        b_ext_unsigned = {33'd0, b_i};

        product_ss = a_ext_signed * b_ext_signed;
        product_su = a_ext_signed * b_ext_unsigned;
        product_uu = a_ext_unsigned * b_ext_unsigned;

        case (funct3_i)
            `F3_MUL:    result_o = product_ss[31:0];
            `F3_MULH:   result_o = product_ss[63:32];
            `F3_MULHSU: result_o = product_su[63:32];
            `F3_MULHU:  result_o = product_uu[63:32];
            default:    result_o = 32'd0;
        endcase
    end

endmodule
