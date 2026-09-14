// =============================================================================
// tb_branch_cmp.sv - 6 condicoes de branch; equality; INT_MIN/INT_MAX; unsigned wrap.
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_branch_cmp;
    logic [31:0] rs1, rs2;
    logic [2:0]  f3;
    logic         taken;
    int errors = 0;

    branch_cmp dut (.rs1_i(rs1), .rs2_i(rs2), .funct3_i(f3), .taken_o(taken));

    task automatic run(input string desc, input [31:0] v1, input [31:0] v2, input [2:0] vf3, input exp);
        begin
            rs1 = v1; rs2 = v2; f3 = vf3; #1;
            `CHECK_EQ(desc, taken, exp);
        end
    endtask

    initial begin
        run("BEQ iguais",        32'd5, 32'd5, `F3_BEQ, 1'b1);
        run("BEQ diferentes",    32'd5, 32'd6, `F3_BEQ, 1'b0);
        run("BNE diferentes",    32'd5, 32'd6, `F3_BNE, 1'b1);
        run("BNE iguais",        32'd5, 32'd5, `F3_BNE, 1'b0);
        run("BLT INT_MIN<INT_MAX", 32'h8000_0000, 32'h7FFF_FFFF, `F3_BLT, 1'b1);
        run("BLT -1<0",          32'hFFFF_FFFF, 32'd0, `F3_BLT, 1'b1);
        run("BGE 5>=5",          32'd5, 32'd5, `F3_BGE, 1'b1);
        run("BGE INT_MAX>=INT_MIN", 32'h7FFF_FFFF, 32'h8000_0000, `F3_BGE, 1'b1);
        run("BLTU 0<max",        32'd0, 32'hFFFF_FFFF, `F3_BLTU, 1'b1);
        run("BLTU max!<0",       32'hFFFF_FFFF, 32'd0, `F3_BLTU, 1'b0);
        run("BGEU max>=0",       32'hFFFF_FFFF, 32'd0, `F3_BGEU, 1'b1);
        run("BGEU 0>=0",         32'd0, 32'd0, `F3_BGEU, 1'b1);

        `TB_FINISH("tb_branch_cmp");
    end
endmodule
