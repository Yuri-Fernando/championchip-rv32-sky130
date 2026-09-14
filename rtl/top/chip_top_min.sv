// =============================================================================
// chip_top_min.sv - Variante MINIMA do top fisico para a PRIMEIRA rodada
// OpenLane baseline (F7). Expoe somente clk_i/rst_i, sem GPIO/serial/debug.
//
// Decisao (ver DECISIONS.md ADR-008): como o pinout GPIO/serial ainda esta
// BLOCKED-PINOUT (SPEC_GAPS.md SG-03) e nenhuma convencao oficial existe,
// qualquer tie-off ja e uma escolha "de risco" para o fluxo fisico (inout
// port sem PAD/ESD real pode confundir sintese/STA de formas dificeis de
// prever). Para nao gastar o primeiro run OpenLane investigando um
// problema que nao vem do CORE, usamos aqui o menor contrato fisico
// possivel e inequivoco. chip_top.sv (com os pinos reservados) continua
// existindo como destino final assim que o pinout oficial for confirmado.
// =============================================================================
module chip_top_min #(
    parameter IMEM_DEPTH_WORDS = 4096,
    parameter DMEM_DEPTH_WORDS = 2048,
    parameter IMEM_HEXFILE     = ""
) (
    input  logic clk_i,
    input  logic rst_i
);

    logic [31:0] pc_dbg_unused;
    logic [3:0]  state_dbg_unused;
    logic         halt_unused, illegal_unused;

    soc_top #(
        .IMEM_DEPTH_WORDS(IMEM_DEPTH_WORDS),
        .DMEM_DEPTH_WORDS(DMEM_DEPTH_WORDS),
        .IMEM_HEXFILE    (IMEM_HEXFILE)
    ) u_soc (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .pc_dbg_o    (pc_dbg_unused),
        .state_dbg_o (state_dbg_unused),
        .halt_o      (halt_unused),
        .illegal_o   (illegal_unused)
    );

endmodule
