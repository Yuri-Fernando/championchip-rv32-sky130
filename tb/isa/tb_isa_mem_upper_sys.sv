// =============================================================================
// tb_isa_mem_upper_sys.sv - 5 loads + 3 stores + 2 upper-imm (LUI/AUIPC) +
// FENCE (no-op) + ECALL (halt, usado aqui como terminador em vez de EBREAK
// para cobrir os dois membros de "sistema/sincronizacao" que interrompem).
// =============================================================================
`include "rv32_defs.vh"
`include "rv32_encode.vh"
`include "tb_utils.vh"

module tb_isa_mem_upper_sys;
    logic clk = 0, rst;
    int errors = 0;
    integer i;
    logic [31:0] auipc_expected;

    soc_top #(.IMEM_DEPTH_WORDS(256), .DMEM_DEPTH_WORDS(64)) dut (
        .clk_i(clk), .rst_i(rst)
    );

    always #5 clk = ~clk;

    initial begin
        logic [31:0] prog [0:31];
        logic [31:0] pc_of;
        i = 0;

        // x1 = base da DMEM
        prog[i] = enc_u(`OPC_LUI, 5'd1, 20'h10010);                              i=i+1; // x1=0x10010000
        // x2 = 0x12345678
        prog[i] = enc_u(`OPC_LUI, 5'd2, 20'h12345);                              i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_OR, 5'd2, 5'd2, 12'h678);              i=i+1;

        // ---- 3 stores -----------------------------------------------------------
        prog[i] = enc_s(`OPC_STORE, `F3_SW, 5'd1, 5'd2, 12'd0);                  i=i+1; // SW [x1+0]=x2
        prog[i] = enc_s(`OPC_STORE, `F3_SH, 5'd1, 5'd2, 12'd4);                  i=i+1; // SH [x1+4]=x2[15:0]
        prog[i] = enc_s(`OPC_STORE, `F3_SB, 5'd1, 5'd2, 12'd8);                  i=i+1; // SB [x1+8]=x2[7:0]

        // ---- 5 loads (rd=x10..x14) -----------------------------------------------
        prog[i] = enc_i(`OPC_LOAD, `F3_LW,  5'd10, 5'd1, 12'd0);                 i=i+1;
        prog[i] = enc_i(`OPC_LOAD, `F3_LH,  5'd11, 5'd1, 12'd4);                 i=i+1;
        prog[i] = enc_i(`OPC_LOAD, `F3_LHU, 5'd12, 5'd1, 12'd4);                 i=i+1;
        prog[i] = enc_i(`OPC_LOAD, `F3_LB,  5'd13, 5'd1, 12'd8);                 i=i+1;
        prog[i] = enc_i(`OPC_LOAD, `F3_LBU, 5'd14, 5'd1, 12'd8);                 i=i+1;

        // ---- 2 upper-imm -----------------------------------------------------------
        prog[i] = enc_u(`OPC_LUI, 5'd15, 20'hABCDE);                             i=i+1; // LUI
        pc_of = `IMEM_BASE + i*4;
        prog[i] = enc_u(`OPC_AUIPC, 5'd16, 20'h1);                               i=i+1; // AUIPC
        auipc_expected = pc_of + 32'h0000_1000;

        // ---- FENCE (no-op) ------------------------------------------------------
        prog[i] = enc_i(`OPC_FENCE, `F3_SYS, 5'd0, 5'd0, 12'd0);                 i=i+1;

        // ---- ECALL (halt) - cobre o 2o membro de sistema/sincronizacao ------------
        prog[i] = enc_i(`OPC_SYSTEM, `F3_SYS, 5'd0, 5'd0, `IMM12_ECALL);         i=i+1;

        for (int k = 0; k < i; k = k + 1) dut.u_imem.mem[k] = prog[k];

        rst = 1; repeat (2) @(negedge clk); rst = 0;

        for (int cyc = 0; cyc < 500 && !dut.halt_o; cyc = cyc + 1) @(negedge clk);
        `CHECK_TRUE("programa atingiu ECALL (halt_o)", dut.halt_o);

        `CHECK_EQ("SW->LW",  dut.u_core.u_regfile.regs[10], 32'h1234_5678);
        `CHECK_EQ("SH->LH (sign, bit15=0)", dut.u_core.u_regfile.regs[11], 32'h0000_5678);
        `CHECK_EQ("SH->LHU", dut.u_core.u_regfile.regs[12], 32'h0000_5678);
        `CHECK_EQ("SB->LB (sign, bit7=0)",  dut.u_core.u_regfile.regs[13], 32'h0000_0078);
        `CHECK_EQ("SB->LBU", dut.u_core.u_regfile.regs[14], 32'h0000_0078);
        `CHECK_EQ("LUI",     dut.u_core.u_regfile.regs[15], 32'hABCD_E000);
        `CHECK_EQ("AUIPC",   dut.u_core.u_regfile.regs[16], auipc_expected);

        `TB_FINISH("tb_isa_mem_upper_sys (5 load+3 store+2 upper+FENCE+ECALL)");
    end
endmodule
