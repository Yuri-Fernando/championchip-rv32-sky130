// =============================================================================
// tb_imm_gen.sv - Vetores I/S/B/U/J incluindo positivos/negativos/extremos.
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_imm_gen;
    logic [31:0] instr, imm;
    logic [2:0]  itype;
    int errors = 0;

    imm_gen dut (.instr_i(instr), .imm_type_i(itype), .imm_o(imm));

    task automatic run(input string desc, input [31:0] vi, input [2:0] vt, input [31:0] exp);
        begin
            instr = vi; itype = vt; #1;
            `CHECK_EQ(desc, imm, exp);
        end
    endtask

    initial begin
        // ADDI x1, x0, 5   -> imm=5
        run("I-type positivo", 32'b000000000101_00000_000_00001_0010011, `IMM_I, 32'd5);
        // ADDI x1, x0, -1  -> imm=-1 (todos 1s)
        run("I-type negativo", 32'b111111111111_00000_000_00001_0010011, `IMM_I, 32'hFFFF_FFFF);

        // SW x2, 4(x1)  -> imm=4  (imm[11:5]=0000000 imm[4:0]=00100)
        run("S-type positivo", {7'b0000000, 5'd2, 5'd1, 3'b010, 5'b00100, 7'b0100011}, `IMM_S, 32'd4);
        // SW com imm negativo -4 -> imm[11:5]=1111111 imm[4:0]=11100
        run("S-type negativo", {7'b1111111, 5'd2, 5'd1, 3'b010, 5'b11100, 7'b0100011}, `IMM_S, 32'hFFFF_FFFC);

        // BEQ com offset +8: imm[12]=0 imm[11]=0 imm[10:5]=000000 imm[4:1]=0100 imm[0]=0(implicito)
        run("B-type positivo +8",
            {1'b0, 6'b000000, 5'd0, 5'd0, 3'b000, 4'b0100, 1'b0, 7'b1100011}, `IMM_B, 32'd8);
        // BEQ offset -8: imm[12]=1 imm[11]=1 imm[10:5]=111111 imm[4:1]=1100
        run("B-type negativo -8",
            {1'b1, 6'b111111, 5'd0, 5'd0, 3'b000, 4'b1100, 1'b1, 7'b1100011}, `IMM_B, 32'hFFFF_FFF8);

        // LUI 0x12345000 -> imm[31:12]=0x12345
        run("U-type", {20'h12345, 5'd1, 7'b0110111}, `IMM_U, 32'h1234_5000);

        // JAL offset +2 (imm[10:1]=bit1=1, resto 0) -> imm = 2
        run("J-type positivo",
            {1'b0, 10'b0000000001, 1'b0, 8'b00000000, 5'd1, 7'b1101111}, `IMM_J, 32'd2);
        // JAL offset -2 (todos bits 1 exceto bit0 implicito=0): imm=-2
        run("J-type negativo -2",
            {1'b1, 10'b1111111111, 1'b1, 8'b11111111, 5'd1, 7'b1101111}, `IMM_J, 32'hFFFF_FFFE);

        `TB_FINISH("tb_imm_gen");
    end
endmodule
