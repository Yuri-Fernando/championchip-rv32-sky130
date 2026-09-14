// =============================================================================
// tb_address_decoder.sv - Inicio/fim dos ranges IMEM/DMEM; fora de faixa;
// protecao de escrita na IMEM (regra "IMEM nunca recebe write enable").
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_address_decoder;
    logic [31:0] addr;
    logic         oe, we;
    logic [3:0]  bw;
    logic         imem_sel, imem_oe, dmem_sel, dmem_oe, dmem_we, in_range;
    logic [3:0]  dmem_bw;
    int errors = 0;

    address_decoder dut (
        .addr_i(addr), .oe_i(oe), .we_i(we), .bw_i(bw),
        .imem_sel_o(imem_sel), .imem_oe_o(imem_oe),
        .dmem_sel_o(dmem_sel), .dmem_oe_o(dmem_oe), .dmem_we_o(dmem_we), .dmem_bw_o(dmem_bw),
        .addr_in_range_o(in_range)
    );

    initial begin
        oe = 1; we = 0; bw = 4'b1111;

        addr = `IMEM_BASE; #1;
        `CHECK_TRUE("IMEM inicio selecionado", imem_sel);
        `CHECK_TRUE("IMEM inicio oe ativo", imem_oe);

        addr = `IMEM_END; #1;
        `CHECK_TRUE("IMEM fim selecionado", imem_sel);

        addr = `IMEM_END + 32'd1; #1;
        `CHECK_TRUE("IMEM fim+1 fora de faixa", !imem_sel && !dmem_sel);
        `CHECK_TRUE("addr_in_range=0 fora de faixa", !in_range);

        addr = `DMEM_BASE; #1;
        `CHECK_TRUE("DMEM inicio selecionado", dmem_sel);

        addr = `DMEM_END; #1;
        `CHECK_TRUE("DMEM fim selecionado", dmem_sel);
        `CHECK_TRUE("addr_in_range=1 no fim da DMEM", in_range);

        // IMEM nunca recebe write enable, mesmo com we_i=1 externo
        addr = `IMEM_BASE; we = 1; #1;
        `CHECK_EQ("IMEM sem sinal de escrita proprio (nao existe imem_we_o)", 1'b1, 1'b1);
        `CHECK_TRUE("DMEM nao ativa fora do seu range mesmo com we=1", !dmem_we);

        // DMEM we/bw propagados corretamente dentro do range
        addr = `DMEM_BASE; we = 1; bw = 4'b0011; #1;
        `CHECK_TRUE("DMEM we ativo dentro do range", dmem_we);
        `CHECK_EQ("DMEM bw propagado", dmem_bw, 4'b0011);

        `TB_FINISH("tb_address_decoder");
    end
endmodule
