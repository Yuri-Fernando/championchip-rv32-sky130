// =============================================================================
// alu.sv - Unidade logico-aritmetica compartilhada.
// Selecao via alu_sel_i (ver `ALU_* em rv32_defs.vh). $signed usado somente
// nos pontos de comparacao/deslocamento aritmetico para nao contaminar
// operacoes unsigned com casts implicitos (regra P6 / secao 5.2 do plano).
// =============================================================================
`include "rv32_defs.vh"

module alu (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic [3:0]  alu_sel_i,
    output logic [31:0] result_o,
    output logic        zero_o
);

    logic [4:0] shamt;
    assign shamt = b_i[4:0]; // shift amount = B[4:0], conforme secao 5.2

    always_comb begin
        case (alu_sel_i)
            `ALU_ADD:   result_o = a_i + b_i;
            `ALU_SUB:   result_o = a_i - b_i;
            `ALU_SLL:   result_o = a_i << shamt;
            `ALU_SLT:   result_o = {31'd0, ($signed(a_i) < $signed(b_i))};
            `ALU_SLTU:  result_o = {31'd0, (a_i < b_i)};
            `ALU_XOR:   result_o = a_i ^ b_i;
            `ALU_SRL:   result_o = a_i >> shamt;
            `ALU_SRA:   result_o = $signed($signed(a_i) >>> shamt);
            `ALU_OR:    result_o = a_i | b_i;
            `ALU_AND:   result_o = a_i & b_i;
            `ALU_PASSB: result_o = b_i;
            default:    result_o = 32'd0;
        endcase
    end

    assign zero_o = (result_o == 32'd0);

endmodule
