// =============================================================================
// soc_top.sv - Top FUNCIONAL de simulacao: core + address_decoder + IMEM/DMEM
// comportamentais. E o alvo usado por toda a verificacao (unit/ISA/firmware).
// O top FISICO de submissao e chip_top.sv, que substitui IMEM/DMEM pela
// estrategia de memoria fisica (macro/template) quando definida pela
// organizacao - ver SPEC_GAPS.md item SG-02.
// =============================================================================
`include "rv32_defs.vh"

module soc_top #(
    parameter IMEM_DEPTH_WORDS = 4096,
    parameter DMEM_DEPTH_WORDS = 2048,
    parameter IMEM_HEXFILE     = ""
) (
    input  logic clk_i,
    input  logic rst_i,

    // Diagnostico exportado para testbench (scoreboard/logs)
    output logic [31:0] pc_dbg_o,
    output logic [3:0]  state_dbg_o,
    output logic         halt_o,
    output logic         illegal_o
);

    logic [31:0] core_addr, core_wdata, core_rdata;
    logic         core_oe, core_we;
    logic [3:0]  core_bw;

    logic         imem_sel, imem_oe;
    logic         dmem_sel, dmem_oe, dmem_we;
    logic [3:0]  dmem_bw;
    logic         addr_in_range;

    logic [31:0] imem_rdata, dmem_rdata;

    rv32_core u_core (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .mem_addr_o  (core_addr),
        .mem_wdata_o (core_wdata),
        .mem_rdata_i (core_rdata),
        .mem_oe_o    (core_oe),
        .mem_we_o    (core_we),
        .mem_bw_o    (core_bw),
        .pc_dbg_o    (pc_dbg_o),
        .state_dbg_o (state_dbg_o),
        .halt_o      (halt_o),
        .illegal_o   (illegal_o)
    );

    address_decoder u_decoder (
        .addr_i          (core_addr),
        .oe_i             (core_oe),
        .we_i             (core_we),
        .bw_i             (core_bw),
        .imem_sel_o      (imem_sel),
        .imem_oe_o       (imem_oe),
        .dmem_sel_o      (dmem_sel),
        .dmem_oe_o       (dmem_oe),
        .dmem_we_o       (dmem_we),
        .dmem_bw_o       (dmem_bw),
        .addr_in_range_o(addr_in_range)
    );

    imem #(
        .DEPTH_WORDS(IMEM_DEPTH_WORDS),
        .BASE_ADDR  (`IMEM_BASE),
        .HEXFILE    (IMEM_HEXFILE)
    ) u_imem (
        .addr_i  (core_addr),
        .oe_i    (imem_oe),
        .rdata_o (imem_rdata)
    );

    dmem #(
        .DEPTH_WORDS(DMEM_DEPTH_WORDS),
        .BASE_ADDR  (`DMEM_BASE)
    ) u_dmem (
        .clk_i   (clk_i),
        .addr_i  (core_addr),
        .oe_i    (dmem_oe),
        .we_i    (dmem_we),
        .bw_i    (dmem_bw),
        .wdata_i (core_wdata),
        .rdata_o (dmem_rdata)
    );

    // Mux de retorno de leitura (rdata ao core), conforme secao 5.6
    assign core_rdata = imem_sel ? imem_rdata :
                         dmem_sel ? dmem_rdata :
                         32'd0;

endmodule
