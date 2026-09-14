// =============================================================================
// branch_cmp.sv - Comparador de branch, 6 condicoes (BEQ/BNE/BLT/BGE/BLTU/BGEU).
// Comparacoes signed/unsigned explicitas conforme regra P6 (secao 5 do plano).
// =============================================================================
`include "rv32_defs.vh"

module branch_cmp (
    input  logic [31:0] rs1_i,
    input  logic [31:0] rs2_i,
    input  logic [2:0]  funct3_i,
    output logic         taken_o
);

    always_comb begin
        case (funct3_i)
            `F3_BEQ:  taken_o = (rs1_i == rs2_i);
            `F3_BNE:  taken_o = (rs1_i != rs2_i);
            `F3_BLT:  taken_o = ($signed(rs1_i) <  $signed(rs2_i));
            `F3_BGE:  taken_o = ($signed(rs1_i) >= $signed(rs2_i));
            `F3_BLTU: taken_o = (rs1_i <  rs2_i);
            `F3_BGEU: taken_o = (rs1_i >= rs2_i);
            default:  taken_o = 1'b0;
        endcase
    end

endmodule
