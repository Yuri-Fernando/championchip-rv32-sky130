// =============================================================================
// chip_top.sv - Top FISICO/submissao (nome exigido pelo fluxo OpenLane:
// DESIGN_NAME=chip_top, ver openlane/config/config.json).
//
// *** STATUS: BLOCKED-PINOUT ***  (ver SPEC_GAPS.md item SG-03)
// O guia oficial menciona 12 pinos (8 GPIO, 2 serial, clock e reset) mas NAO
// detalha o comportamento dos perifericos (mapeamento de endereco, protocolo
// serial, direcao/mux dos GPIO). Por regra do Plano Mestre (P4 spec-first /
// R10), esses perifericos NAO sao inventados aqui. Este top expoe apenas
// clk_i/rst_i (contrato minimo e inequivoco) e instancia o SoC funcional;
// os 8 pinos GPIO e 2 pinos seriais ficam reservados (tie-off) ate que o
// template/pinout oficial da organizacao seja confirmado - trocar por I/O
// real e a ULTIMA etapa antes do fechamento fisico definitivo.
//
// rst_i: polaridade assumida ativo-alto (padrao SKY130/OpenLane); CONFIRMAR
// contra o template oficial antes do freeze fisico (ver secao 3.3 do plano).
// =============================================================================
module chip_top #(
    parameter IMEM_DEPTH_WORDS = 4096,
    parameter DMEM_DEPTH_WORDS = 2048,
    parameter IMEM_HEXFILE     = ""
) (
    input  logic clk_i,
    input  logic rst_i,

    // Reservados - BLOCKED-PINOUT (ver banner acima); nao conectados a logica
    // funcional ate confirmacao oficial. Mantidos na interface para que o
    // nome/posicao dos pinos ja exista quando o comportamento for definido.
    inout  wire [7:0] gpio_io,
    output logic        uart_tx_o,
    input  logic         uart_rx_i
);

    logic [31:0] pc_dbg, halt_dbg_bit;
    logic [3:0]  state_dbg;
    logic         halt, illegal;

    soc_top #(
        .IMEM_DEPTH_WORDS(IMEM_DEPTH_WORDS),
        .DMEM_DEPTH_WORDS(DMEM_DEPTH_WORDS),
        .IMEM_HEXFILE    (IMEM_HEXFILE)
    ) u_soc (
        .clk_i       (clk_i),
        .rst_i       (rst_i),
        .pc_dbg_o    (pc_dbg),
        .state_dbg_o (state_dbg),
        .halt_o      (halt),
        .illegal_o   (illegal)
    );

    // GPIO/UART: tie-off seguro ate definicao oficial (nao sintetiza logica
    // "inventada"; evita pinos flutuantes no fechamento fisico).
    assign gpio_io   = 8'bz;
    assign uart_tx_o = 1'b0;

endmodule
