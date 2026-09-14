// =============================================================================
// tb_lsu.sv - Load (todos offsets validos; sign/zero extend; 8/16/32-bit) e
// Store (bw + deslocamento para todos offsets; halfword e word alinhados).
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_lsu;
    logic [1:0]  addr_lsb;
    logic [2:0]  f3;
    logic         is_store;
    logic [31:0] store_data, mem_rdata, mem_wdata, load_data;
    logic [3:0]  bw;
    logic         misaligned;
    int errors = 0;

    lsu dut (
        .addr_lsb_i(addr_lsb), .funct3_i(f3), .is_store_i(is_store),
        .store_data_i(store_data), .mem_rdata_i(mem_rdata),
        .mem_wdata_o(mem_wdata), .bw_o(bw), .load_data_o(load_data),
        .misaligned_o(misaligned)
    );

    // Palavra de teste: bytes {b3,b2,b1,b0} = {0x80,0x02,0x81,0x7F}
    // b0=0x7F(+127) b1=0x81(-127 signed) b2=0x02 b3=0x80(-128 signed)
    localparam [31:0] WORD = 32'h8002_817F;

    task automatic run_load(input string desc, input [1:0] alsb, input [2:0] vf3, input [31:0] exp);
        begin
            is_store = 0; addr_lsb = alsb; f3 = vf3; mem_rdata = WORD; #1;
            `CHECK_EQ(desc, load_data, exp);
        end
    endtask

    task automatic run_store(input string desc, input [1:0] alsb, input [2:0] vf3, input [3:0] exp_bw);
        begin
            is_store = 1; addr_lsb = alsb; f3 = vf3; store_data = 32'hCAFEBABE; #1;
            `CHECK_EQ(desc, bw, exp_bw);
        end
    endtask

    initial begin
        // LB em cada offset (sign extend)
        run_load("LB off0 (+0x7F)", 2'b00, `F3_LB, 32'h0000_007F);
        run_load("LB off1 (-0x7F signed)", 2'b01, `F3_LB, 32'hFFFF_FF81);
        run_load("LB off2 (+0x02)", 2'b10, `F3_LB, 32'h0000_0002);
        run_load("LB off3 (-0x80 signed)", 2'b11, `F3_LB, 32'hFFFF_FF80);
        // LBU (zero extend)
        run_load("LBU off1", 2'b01, `F3_LBU, 32'h0000_0081);
        run_load("LBU off3", 2'b11, `F3_LBU, 32'h0000_0080);
        // LH (halfword, addr[1] seleciona metade)
        run_load("LH metade baixa (0x817F -> sign neg)", 2'b00, `F3_LH, 32'hFFFF_817F);
        run_load("LH metade alta (0x8002 -> sign neg)", 2'b10, `F3_LH, 32'hFFFF_8002);
        // LHU
        run_load("LHU metade baixa", 2'b00, `F3_LHU, 32'h0000_817F);
        run_load("LHU metade alta", 2'b10, `F3_LHU, 32'h0000_8002);
        // LW
        run_load("LW palavra completa", 2'b00, `F3_LW, WORD);

        // Store: bw e deslocamento por offset
        run_store("SB off0", 2'b00, `F3_SB, 4'b0001);
        run_store("SB off1", 2'b01, `F3_SB, 4'b0010);
        run_store("SB off2", 2'b10, `F3_SB, 4'b0100);
        run_store("SB off3", 2'b11, `F3_SB, 4'b1000);
        run_store("SH off0 (metade baixa)", 2'b00, `F3_SH, 4'b0011);
        run_store("SH off2 (metade alta)", 2'b10, `F3_SH, 4'b1100);
        run_store("SW", 2'b00, `F3_SW, 4'b1111);

        // bw deve ser zero quando nao e store
        is_store = 0; f3 = `F3_SW; addr_lsb = 2'b00; #1;
        `CHECK_EQ("bw=0 fora de store", bw, 4'b0000);

        // Desalinhamento
        is_store = 0; f3 = `F3_LW; addr_lsb = 2'b01; #1;
        `CHECK_TRUE("LW desalinhado sinalizado", misaligned);
        is_store = 0; f3 = `F3_LH; addr_lsb = 2'b01; #1;
        `CHECK_TRUE("LH desalinhado sinalizado", misaligned);
        is_store = 0; f3 = `F3_LW; addr_lsb = 2'b00; #1;
        `CHECK_TRUE("LW alinhado sem flag", !misaligned);

        `TB_FINISH("tb_lsu");
    end
endmodule
