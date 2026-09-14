// =============================================================================
// imm_gen.sv - Gerador de imediatos I/S/B/U/J com sign extension (RV32I).
// imm_type_i usa as constantes `IMM_* de rv32_defs.vh.
// =============================================================================
`include "rv32_defs.vh"

module imm_gen (
    input  logic [31:0] instr_i,
    input  logic [2:0]  imm_type_i,
    output logic [31:0] imm_o
);

    always_comb begin
        case (imm_type_i)
            `IMM_I:  imm_o = {{20{instr_i[31]}}, instr_i[31:20]};

            `IMM_S:  imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};

            `IMM_B:  imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                              instr_i[30:25], instr_i[11:8], 1'b0};

            `IMM_U:  imm_o = {instr_i[31:12], 12'd0};

            `IMM_J:  imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                              instr_i[20], instr_i[30:21], 1'b0};

            default: imm_o = 32'd0;
        endcase
    end

endmodule
