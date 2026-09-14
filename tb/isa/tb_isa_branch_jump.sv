// =============================================================================
// tb_isa_branch_jump.sv - 6 condicoes de branch (taken + not-taken = 12
// checagens via contador x31) + JAL + JALR (2/2 jump), via soc_top.
//
// Padrao "taken": BRANCH +8 ; poison(x31-=1000) ; landing(x31+=1).
//   Correto (tomado): pula o poison -> x31 += 1.
//   Bug (nao tomado): executa poison depois landing -> x31 += -1000+1 = -999.
// Padrao "not-taken": BRANCH +12 ; x31+=1 ; JAL +8(skip poison) ; poison(x31+=5000).
//   Correto (nao tomado): cai no +1, JAL pula o poison -> x31 += 1.
//   Bug (tomado): pula direto para o poison -> x31 += 5000.
// =============================================================================
`include "rv32_defs.vh"
`include "rv32_encode.vh"
`include "tb_utils.vh"

module tb_isa_branch_jump;
    logic clk = 0, rst;
    int errors = 0;
    integer i;
    logic [31:0] jal_link_expected, jalr_link_expected, target_addr, auipc_addr;

    soc_top #(.IMEM_DEPTH_WORDS(256), .DMEM_DEPTH_WORDS(64)) dut (
        .clk_i(clk), .rst_i(rst)
    );

    always #5 clk = ~clk;

    initial begin
        logic [31:0] prog [0:63];
        i = 0;

        // ---- setup ---------------------------------------------------------------
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd1, 5'd0, 12'd5);   i=i+1; // x1=5
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd2, 5'd0, 12'd5);   i=i+1; // x2=5
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd3, 5'd0, 12'd6);   i=i+1; // x3=6
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd4, 5'd0, -12'sd1); i=i+1; // x4=0xFFFFFFFF

        // ---- 6 condicoes x (taken, not-taken) -------------------------------------
        // BEQ
        prog[i] = enc_b(`OPC_BRANCH, `F3_BEQ, 5'd1, 5'd2, 13'sd8);  i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,-12'sd1000); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;

        prog[i] = enc_b(`OPC_BRANCH, `F3_BEQ, 5'd1, 5'd3, 13'sd12); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;
        prog[i] = enc_j(`OPC_JAL, 5'd0, 21'sd8);                          i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd2047);  i=i+1; // poison (~5000 truncado ao max de 12b; ok p/ detectar bug)

        // BNE
        prog[i] = enc_b(`OPC_BRANCH, `F3_BNE, 5'd1, 5'd3, 13'sd8);  i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,-12'sd1000); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;

        prog[i] = enc_b(`OPC_BRANCH, `F3_BNE, 5'd1, 5'd2, 13'sd12); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;
        prog[i] = enc_j(`OPC_JAL, 5'd0, 21'sd8);                          i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd2047);  i=i+1;

        // BLT
        prog[i] = enc_b(`OPC_BRANCH, `F3_BLT, 5'd4, 5'd1, 13'sd8);  i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,-12'sd1000); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;

        prog[i] = enc_b(`OPC_BRANCH, `F3_BLT, 5'd1, 5'd4, 13'sd12); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;
        prog[i] = enc_j(`OPC_JAL, 5'd0, 21'sd8);                          i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd2047);  i=i+1;

        // BGE
        prog[i] = enc_b(`OPC_BRANCH, `F3_BGE, 5'd1, 5'd4, 13'sd8);  i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,-12'sd1000); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;

        prog[i] = enc_b(`OPC_BRANCH, `F3_BGE, 5'd4, 5'd1, 13'sd12); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;
        prog[i] = enc_j(`OPC_JAL, 5'd0, 21'sd8);                          i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd2047);  i=i+1;

        // BLTU
        prog[i] = enc_b(`OPC_BRANCH, `F3_BLTU, 5'd1, 5'd4, 13'sd8);  i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,-12'sd1000); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;

        prog[i] = enc_b(`OPC_BRANCH, `F3_BLTU, 5'd4, 5'd1, 13'sd12); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;
        prog[i] = enc_j(`OPC_JAL, 5'd0, 21'sd8);                          i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd2047);  i=i+1;

        // BGEU
        prog[i] = enc_b(`OPC_BRANCH, `F3_BGEU, 5'd4, 5'd1, 13'sd8);  i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,-12'sd1000); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;

        prog[i] = enc_b(`OPC_BRANCH, `F3_BGEU, 5'd1, 5'd4, 13'sd12); i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd1);     i=i+1;
        prog[i] = enc_j(`OPC_JAL, 5'd0, 21'sd8);                          i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd31,5'd31,12'd2047);  i=i+1;

        // ---- JAL dedicado (rd=x20; landing marca x21=111, poison x21=777) --------
        jal_link_expected = `IMEM_BASE + (i+1)*4;
        prog[i] = enc_j(`OPC_JAL, 5'd20, 21'sd8);                         i=i+1;
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd21,5'd0,12'd777);    i=i+1; // poison
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd21,5'd0,12'd111);    i=i+1; // landing

        // ---- JALR dedicado (via AUIPC+ADDI p/ montar endereco absoluto+1) --------
        auipc_addr = `IMEM_BASE + i*4;
        prog[i] = enc_u(`OPC_AUIPC, 5'd5, 20'h0);                          i=i+1; // x5 = auipc_addr
        // target = landing da JALR, calculado a seguir (3 instrucoes depois do ADDI)
        target_addr = auipc_addr + 4*4; // AUIPC, ADDI, JALR, poison, [landing] -> +4 instr
        prog[i] = enc_i(`OPC_ALU_IMM, `F3_ADD_SUB, 5'd5, 5'd5,
                          (target_addr - auipc_addr + 1)); i=i+1; // x5 = target+1 (testa mascara LSB)
        jalr_link_expected = `IMEM_BASE + (i+1)*4;
        prog[i] = enc_i(`OPC_JALR, `F3_SYS, 5'd22, 5'd5, 12'd0);          i=i+1; // JALR x22, x5, 0
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd23,5'd0,12'd777);    i=i+1; // poison
        prog[i] = enc_i(`OPC_ALU_IMM,`F3_ADD_SUB,5'd23,5'd0,12'd222);    i=i+1; // landing

        prog[i] = enc_i(`OPC_SYSTEM, `F3_SYS, 5'd0, 5'd0, `IMM12_EBREAK); i=i+1;

        for (int k = 0; k < i; k = k + 1) dut.u_imem.mem[k] = prog[k];

        rst = 1; repeat (2) @(negedge clk); rst = 0;
        for (int cyc = 0; cyc < 900 && !dut.halt_o; cyc = cyc + 1) @(negedge clk);
        `CHECK_TRUE("programa atingiu EBREAK (halt_o)", dut.halt_o);

        `CHECK_EQ("6 branches x2 (taken+not-taken) => x31==12",
                  dut.u_core.u_regfile.regs[31], 32'd12);
        `CHECK_EQ("JAL link (rd=PC+4)", dut.u_core.u_regfile.regs[20], jal_link_expected);
        `CHECK_EQ("JAL destino (pulou poison, x21=111)", dut.u_core.u_regfile.regs[21], 32'd111);
        `CHECK_EQ("JALR link (rd=PC+4)", dut.u_core.u_regfile.regs[22], jalr_link_expected);
        `CHECK_EQ("JALR destino com mascara LSB (x23=222)", dut.u_core.u_regfile.regs[23], 32'd222);

        `TB_FINISH("tb_isa_branch_jump (6 branch x2 + JAL + JALR)");
    end
endmodule
