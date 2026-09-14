// =============================================================================
// address_decoder.sv - Roteamento de endereco entre IMEM e DMEM (mapa da
// secao 5.6/8.1 do Plano Mestre). IMEM e somente leitura (we sempre
// bloqueado); enderecos fora de faixa nao selecionam nenhuma memoria
// (rdata_o = 0, protecao contra escrita fantasma).
// =============================================================================
`include "rv32_defs.vh"

module address_decoder (
    input  logic [31:0] addr_i,
    input  logic         oe_i,
    input  logic         we_i,
    input  logic [3:0]   bw_i,

    output logic         imem_sel_o,
    output logic         imem_oe_o,

    output logic         dmem_sel_o,
    output logic         dmem_oe_o,
    output logic         dmem_we_o,
    output logic [3:0]   dmem_bw_o,

    output logic         addr_in_range_o
);

    logic in_imem, in_dmem;

    assign in_imem = (addr_i >= `IMEM_BASE) && (addr_i <= `IMEM_END);
    assign in_dmem = (addr_i >= `DMEM_BASE) && (addr_i <= `DMEM_END);

    assign imem_sel_o = in_imem;
    assign imem_oe_o  = in_imem && oe_i; // IMEM: we_i e ignorado por design (ROM)

    assign dmem_sel_o = in_dmem;
    assign dmem_oe_o  = in_dmem && oe_i;
    assign dmem_we_o  = in_dmem && we_i;
    assign dmem_bw_o  = in_dmem ? bw_i : 4'b0000;

    assign addr_in_range_o = in_imem || in_dmem;

endmodule
