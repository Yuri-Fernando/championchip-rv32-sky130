// =============================================================================
// tb_isa_alu.sv - Teste dirigido por instrucao (whitebox): as 10 ALU reg-reg
// + 9 ALU reg-imm (19/40 RV32I) executadas via soc_top, com scoreboard
// direto no regfile (dut.u_core.u_regfile.regs[n]) - secao 7.3 do Plano
// Mestre ("scoreboard compara PC, rd esperado, memoria modificada").
// =============================================================================
`include "rv32_defs.vh"
`include "rv32_encode.vh"
`include "tb_utils.vh"

module tb_isa_alu;
    logic clk = 0, rst;
    int errors = 0;
    integer i;

    soc_top #(.IMEM_DEPTH_WORDS(256), .DMEM_DEPTH_WORDS(64)) dut (
        .clk_i(clk), .rst_i(rst)
    );

    always #5 clk = ~clk;

    localparam [6:0] OPC_R = `OPC_ALU_REG;
    localparam [6:0] OPC_I = `OPC_ALU_IMM;

    initial begin
        logic [31:0] prog [0:31];
        i = 0;
        // ---- setup ----------------------------------------------------------
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd1, 5'd0, 12'd12);           i=i+1; // x1=12
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd2, 5'd0, 12'd5);            i=i+1; // x2=5
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd3, 5'd0, -12'sd1);          i=i+1; // x3=-1
        prog[i] = enc_u(`OPC_LUI, 5'd4, 20'h80000);                                i=i+1; // x4=INT_MIN

        // ---- R-type (rd=x10..x19) --------------------------------------------
        prog[i] = enc_r(OPC_R, `F3_ADD_SUB, `F7_ALU_BASE, 5'd10, 5'd1, 5'd2); i=i+1; // ADD
        prog[i] = enc_r(OPC_R, `F3_ADD_SUB, `F7_ALU_ALT,  5'd11, 5'd1, 5'd2); i=i+1; // SUB
        prog[i] = enc_r(OPC_R, `F3_SLL,     `F7_ALU_BASE, 5'd12, 5'd2, 5'd1); i=i+1; // SLL
        prog[i] = enc_r(OPC_R, `F3_SLT,     `F7_ALU_BASE, 5'd13, 5'd4, 5'd1); i=i+1; // SLT
        prog[i] = enc_r(OPC_R, `F3_SLTU,    `F7_ALU_BASE, 5'd14, 5'd4, 5'd1); i=i+1; // SLTU
        prog[i] = enc_r(OPC_R, `F3_XOR,     `F7_ALU_BASE, 5'd15, 5'd1, 5'd3); i=i+1; // XOR
        prog[i] = enc_r(OPC_R, `F3_SRL_SRA, `F7_ALU_BASE, 5'd16, 5'd4, 5'd2); i=i+1; // SRL
        prog[i] = enc_r(OPC_R, `F3_SRL_SRA, `F7_ALU_ALT,  5'd17, 5'd4, 5'd2); i=i+1; // SRA
        prog[i] = enc_r(OPC_R, `F3_OR,      `F7_ALU_BASE, 5'd18, 5'd1, 5'd2); i=i+1; // OR
        prog[i] = enc_r(OPC_R, `F3_AND,     `F7_ALU_BASE, 5'd19, 5'd1, 5'd2); i=i+1; // AND

        // ---- I-type (rd=x20..x28) --------------------------------------------
        prog[i] = enc_i(OPC_I, `F3_ADD_SUB, 5'd20, 5'd1, 12'd10);                i=i+1; // ADDI
        prog[i] = enc_i(OPC_I, `F3_SLT,     5'd21, 5'd4, 12'd0);                 i=i+1; // SLTI
        prog[i] = enc_i(OPC_I, `F3_SLTU,    5'd22, 5'd4, 12'd1);                 i=i+1; // SLTIU
        prog[i] = enc_i(OPC_I, `F3_XOR,     5'd23, 5'd1, -12'sd1);               i=i+1; // XORI
        prog[i] = enc_i(OPC_I, `F3_OR,      5'd24, 5'd1, 12'd3);                 i=i+1; // ORI
        prog[i] = enc_i(OPC_I, `F3_AND,     5'd25, 5'd1, 12'd9);                 i=i+1; // ANDI
        prog[i] = enc_ishift(OPC_I, `F3_SLL,     `F7_ALU_BASE, 5'd26, 5'd2, 5'd3); i=i+1; // SLLI
        prog[i] = enc_ishift(OPC_I, `F3_SRL_SRA, `F7_ALU_BASE, 5'd27, 5'd4, 5'd4); i=i+1; // SRLI
        prog[i] = enc_ishift(OPC_I, `F3_SRL_SRA, `F7_ALU_ALT,  5'd28, 5'd4, 5'd4); i=i+1; // SRAI

        // ---- fim --------------------------------------------------------------
        prog[i] = enc_i(`OPC_SYSTEM, `F3_SYS, 5'd0, 5'd0, `IMM12_EBREAK);        i=i+1;

        for (int k = 0; k < i; k = k + 1) dut.u_imem.mem[k] = prog[k];

        rst = 1; repeat (2) @(negedge clk); rst = 0;

        // roda ate halt_o ou timeout
        for (int cyc = 0; cyc < 500 && !dut.halt_o; cyc = cyc + 1) @(negedge clk);
        `CHECK_TRUE("programa atingiu EBREAK (halt_o)", dut.halt_o);

        `CHECK_EQ("ADD",  dut.u_core.u_regfile.regs[10], 32'd17);
        `CHECK_EQ("SUB",  dut.u_core.u_regfile.regs[11], 32'd7);
        `CHECK_EQ("SLL",  dut.u_core.u_regfile.regs[12], 32'd20480);
        `CHECK_EQ("SLT",  dut.u_core.u_regfile.regs[13], 32'd1);
        `CHECK_EQ("SLTU", dut.u_core.u_regfile.regs[14], 32'd0);
        `CHECK_EQ("XOR",  dut.u_core.u_regfile.regs[15], 32'hFFFF_FFF3);
        `CHECK_EQ("SRL",  dut.u_core.u_regfile.regs[16], 32'h0400_0000);
        `CHECK_EQ("SRA",  dut.u_core.u_regfile.regs[17], 32'hFC00_0000);
        `CHECK_EQ("OR",   dut.u_core.u_regfile.regs[18], 32'd13);
        `CHECK_EQ("AND",  dut.u_core.u_regfile.regs[19], 32'd4);

        `CHECK_EQ("ADDI",  dut.u_core.u_regfile.regs[20], 32'd22);
        `CHECK_EQ("SLTI",  dut.u_core.u_regfile.regs[21], 32'd1);
        `CHECK_EQ("SLTIU", dut.u_core.u_regfile.regs[22], 32'd0);
        `CHECK_EQ("XORI",  dut.u_core.u_regfile.regs[23], 32'hFFFF_FFF3);
        `CHECK_EQ("ORI",   dut.u_core.u_regfile.regs[24], 32'd15);
        `CHECK_EQ("ANDI",  dut.u_core.u_regfile.regs[25], 32'd8);
        `CHECK_EQ("SLLI",  dut.u_core.u_regfile.regs[26], 32'd40);
        `CHECK_EQ("SRLI",  dut.u_core.u_regfile.regs[27], 32'h0800_0000);
        `CHECK_EQ("SRAI",  dut.u_core.u_regfile.regs[28], 32'hF800_0000);

        `TB_FINISH("tb_isa_alu (19/40 RV32I ALU reg+imm)");
    end
endmodule
