// =============================================================================
// tb_regfile.sv - x0 fixo em zero; escrita/leitura para os demais 31 regs;
// reset zera tudo (ver secao 7.2 do Plano Mestre).
// =============================================================================
`include "tb_utils.vh"

module tb_regfile;
    logic        clk = 0, rst;
    logic [4:0]  rs1, rs2, rd;
    logic [31:0] wdata, rs1_d, rs2_d;
    logic         we;
    int errors = 0;

    regfile dut (
        .clk_i(clk), .rst_i(rst),
        .rs1_addr_i(rs1), .rs2_addr_i(rs2),
        .rd_addr_i(rd), .rd_wdata_i(wdata), .rd_we_i(we),
        .rs1_rdata_o(rs1_d), .rs2_rdata_o(rs2_d)
    );

    always #5 clk = ~clk;

    task automatic write_reg(input [4:0] addr, input [31:0] data);
        begin
            @(negedge clk); rd = addr; wdata = data; we = 1;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        rst = 1; rs1 = 0; rs2 = 0; rd = 0; wdata = 0; we = 0;
        @(negedge clk); @(negedge clk); rst = 0;

        // x0 sempre zero, mesmo apos tentativa de escrita
        write_reg(5'd0, 32'hFFFF_FFFF);
        rs1 = 5'd0; #1;
        `CHECK_EQ("x0 ignora escrita", rs1_d, 32'd0);

        // escreve em x1..x31 e le de volta
        write_reg(5'd1, 32'hDEAD_BEEF);
        write_reg(5'd31, 32'h1234_5678);
        rs1 = 5'd1; rs2 = 5'd31; #1;
        `CHECK_EQ("x1 valor gravado", rs1_d, 32'hDEAD_BEEF);
        `CHECK_EQ("x31 valor gravado", rs2_d, 32'h1234_5678);

        // leitura same-cycle da escrita anterior (assincrona, ja refletida)
        write_reg(5'd5, 32'hA5A5_A5A5);
        rs1 = 5'd5; #1;
        `CHECK_EQ("x5 leitura pos-escrita", rs1_d, 32'hA5A5_A5A5);

        // reset zera tudo
        rst = 1; @(negedge clk); rst = 0;
        rs1 = 5'd1; rs2 = 5'd31; #1;
        `CHECK_EQ("x1 apos reset", rs1_d, 32'd0);
        `CHECK_EQ("x31 apos reset", rs2_d, 32'd0);

        `TB_FINISH("tb_regfile");
    end
endmodule
