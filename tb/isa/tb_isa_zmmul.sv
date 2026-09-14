// =============================================================================
// tb_isa_zmmul.sv - MUL/MULH/MULHSU/MULHU (4/4 Zmmul) executadas via soc_top.
// =============================================================================
`include "rv32_defs.vh"
`include "rv32_encode.vh"
`include "tb_utils.vh"

module tb_isa_zmmul;
    logic clk = 0, rst;
    int errors = 0;
    integer i;

    soc_top #(.IMEM_DEPTH_WORDS(256), .DMEM_DEPTH_WORDS(64)) dut (
        .clk_i(clk), .rst_i(rst)
    );

    always #5 clk = ~clk;

    initial begin
        logic [31:0] prog [0:31];
        i = 0;

        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd1, 5'd0, 12'd7);           i=i+1; // x1=7
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd2, 5'd0, -12'sd3);         i=i+1; // x2=-3
        prog[i] = enc_u(`OPC_LUI, 5'd3, 20'hFFFFF);                                i=i+1; // x3=0xFFFFF000
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_OR, 5'd3, 5'd3, -12'sd1);              i=i+1; // x3=0xFFFFFFFF (-1)

        prog[i] = enc_r(`OPC_ALU_REG, `F3_MUL,    `F7_ZMMUL, 5'd10, 5'd1, 5'd2); i=i+1; // MUL 7*-3=-21
        prog[i] = enc_r(`OPC_ALU_REG, `F3_MULH,   `F7_ZMMUL, 5'd11, 5'd1, 5'd2); i=i+1; // MULH (high=-1, sinal)
        prog[i] = enc_r(`OPC_ALU_REG, `F3_MULHSU, `F7_ZMMUL, 5'd12, 5'd2, 5'd1); i=i+1; // MULHSU(-3 signed * 7 unsigned)
        prog[i] = enc_r(`OPC_ALU_REG, `F3_MULHU,  `F7_ZMMUL, 5'd13, 5'd3, 5'd3); i=i+1; // MULHU max*max

        prog[i] = enc_i(`OPC_SYSTEM, `F3_SYS, 5'd0, 5'd0, `IMM12_EBREAK);        i=i+1;

        for (int k = 0; k < i; k = k + 1) dut.u_imem.mem[k] = prog[k];

        rst = 1; repeat (2) @(negedge clk); rst = 0;
        for (int cyc = 0; cyc < 300 && !dut.halt_o; cyc = cyc + 1) @(negedge clk);
        `CHECK_TRUE("programa atingiu EBREAK (halt_o)", dut.halt_o);

        // 7 * -3 = -21 = 0xFFFFFFEB
        `CHECK_EQ("MUL 7*-3",    dut.u_core.u_regfile.regs[10], 32'hFFFF_FFEB);
        // high32 de 7*(-3) (64-bit signed) = -1 (0xFFFFFFFF), pois produto=-21 cabe em 32 bits
        `CHECK_EQ("MULH 7*-3",   dut.u_core.u_regfile.regs[11], 32'hFFFF_FFFF);
        // MULHSU: rs1=x2=-3 (signed), rs2=x1=7 (unsigned) -> produto=-21 -> high=0xFFFFFFFF
        `CHECK_EQ("MULHSU -3*7", dut.u_core.u_regfile.regs[12], 32'hFFFF_FFFF);
        // MULHU: 0xFFFFFFFF*0xFFFFFFFF -> high=0xFFFFFFFE
        `CHECK_EQ("MULHU max*max", dut.u_core.u_regfile.regs[13], 32'hFFFF_FFFE);

        `TB_FINISH("tb_isa_zmmul (4/4 Zmmul)");
    end
endmodule
