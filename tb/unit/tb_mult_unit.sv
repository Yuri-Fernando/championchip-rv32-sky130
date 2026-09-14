// =============================================================================
// tb_mult_unit.sv - MUL/MULH/MULHSU/MULHU com casos extremos
// (0,1,-1,INT_MIN,INT_MAX,0xFFFFFFFF) + combinacoes signed/unsigned.
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_mult_unit;
    logic [31:0] a, b, result;
    logic [2:0]  f3;
    int errors = 0;

    mult_unit dut (.a_i(a), .b_i(b), .funct3_i(f3), .result_o(result));

    task automatic run(input string desc, input [31:0] va, input [31:0] vb, input [2:0] vf3, input [31:0] exp);
        begin
            a = va; b = vb; f3 = vf3; #1;
            `CHECK_EQ(desc, result, exp);
        end
    endtask

    initial begin
        // MUL: low32 de a*b, independente de signedness (bits baixos identicos)
        run("MUL 3*4",         32'd3, 32'd4, `F3_MUL, 32'd12);
        run("MUL -1*-1=1",     32'hFFFFFFFF, 32'hFFFFFFFF, `F3_MUL, 32'd1);
        run("MUL 0*qualquer",  32'd0, 32'hDEADBEEF, `F3_MUL, 32'd0);
        run("MUL overflow low",32'h0001_0000, 32'h0001_0000, `F3_MUL, 32'd0); // 2^32 -> low=0

        // MULH: high32 signed*signed
        run("MULH -1*-1=0",    32'hFFFFFFFF, 32'hFFFFFFFF, `F3_MULH, 32'd0);
        run("MULH INT_MIN*-1", 32'h8000_0000, 32'hFFFFFFFF, `F3_MULH, 32'h0000_0000); // resultado 64b = 0x0000000080000000 -> high=0
        run("MULH INT_MAX*INT_MAX", 32'h7FFFFFFF, 32'h7FFFFFFF, `F3_MULH, 32'h3FFF_FFFF);
        run("MULH 1*-1=high(-1)", 32'd1, 32'hFFFFFFFF, `F3_MULH, 32'hFFFF_FFFF);

        // MULHSU: high32 signed(a) * unsigned(b)
        run("MULHSU -1(signed)*1(uns)", 32'hFFFFFFFF, 32'd1, `F3_MULHSU, 32'hFFFF_FFFF);
        run("MULHSU 1*0xFFFFFFFF(uns)", 32'd1, 32'hFFFFFFFF, `F3_MULHSU, 32'd0);

        // MULHU: high32 unsigned*unsigned
        run("MULHU max*max", 32'hFFFFFFFF, 32'hFFFFFFFF, `F3_MULHU, 32'hFFFF_FFFE);
        run("MULHU 0*max",   32'd0, 32'hFFFFFFFF, `F3_MULHU, 32'd0);

        `TB_FINISH("tb_mult_unit");
    end
endmodule
