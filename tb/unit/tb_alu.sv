// =============================================================================
// tb_alu.sv - Teste unitario da ALU (11 selects; 0/1/-1; overflow modular;
// shifts 0/31; comparacao signed/unsigned) - ver secao 7.2 do Plano Mestre.
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_alu;
    logic [31:0] a, b, result;
    logic [3:0]  sel;
    logic         zero;
    int errors = 0;

    alu dut (.a_i(a), .b_i(b), .alu_sel_i(sel), .result_o(result), .zero_o(zero));

    task automatic run(input string desc, input [31:0] va, input [31:0] vb, input [3:0] vsel, input [31:0] exp);
        begin
            a = va; b = vb; sel = vsel; #1;
            `CHECK_EQ(desc, result, exp);
        end
    endtask

    initial begin
        // ADD
        run("ADD 1+1",            32'd1, 32'd1, `ALU_ADD, 32'd2);
        run("ADD overflow wrap",  32'hFFFFFFFF, 32'd1, `ALU_ADD, 32'd0);
        // SUB
        run("SUB 5-3",            32'd5, 32'd3, `ALU_SUB, 32'd2);
        run("SUB underflow wrap", 32'd0, 32'd1, `ALU_SUB, 32'hFFFFFFFF);
        // SLL
        run("SLL by 0",           32'h1, 32'd0, `ALU_SLL, 32'h1);
        run("SLL by 31",          32'h1, 32'd31, `ALU_SLL, 32'h8000_0000);
        // SLT (signed)
        run("SLT -1 < 1",         32'hFFFFFFFF, 32'd1, `ALU_SLT, 32'd1);
        run("SLT INT_MIN<INT_MAX",32'h8000_0000, 32'h7FFF_FFFF, `ALU_SLT, 32'd1);
        run("SLT equal",          32'd5, 32'd5, `ALU_SLT, 32'd0);
        // SLTU (unsigned)
        run("SLTU -1(big) < 1 = 0", 32'hFFFFFFFF, 32'd1, `ALU_SLTU, 32'd0);
        run("SLTU 0 < max",       32'd0, 32'hFFFFFFFF, `ALU_SLTU, 32'd1);
        // XOR/OR/AND
        run("XOR",  32'hAAAAAAAA, 32'hFFFFFFFF, `ALU_XOR, 32'h55555555);
        run("OR",   32'hF0F0F0F0, 32'h0F0F0F0F, `ALU_OR,  32'hFFFFFFFF);
        run("AND",  32'hFFFFFFFF, 32'h0000FFFF, `ALU_AND, 32'h0000FFFF);
        // SRL/SRA
        run("SRL by 0",           32'h8000_0000, 32'd0, `ALU_SRL, 32'h8000_0000);
        run("SRL by 31",          32'h8000_0000, 32'd31, `ALU_SRL, 32'h1);
        run("SRA neg by 4",       32'hF0000000, 32'd4, `ALU_SRA, 32'hFF000000);
        run("SRA pos by 31",      32'h7FFFFFFF, 32'd31, `ALU_SRA, 32'h0);
        // PASSB (LUI)
        run("PASSB",              32'hDEADBEEF, 32'h1234_5000, `ALU_PASSB, 32'h1234_5000);

        `TB_FINISH("tb_alu");
    end
endmodule
