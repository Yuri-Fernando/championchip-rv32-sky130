// =============================================================================
// dmem.sv - Modelo de data memory (SRAM) sincrona, 8 KiB, base 0x1001_0000.
//
// O guia afirma explicitamente que a DMEM e sincrona, com a operacao
// terminando apos um clock: rdata_o so fica valido um ciclo depois de oe_i,
// o que exige o estado MEM_WAIT na FSM do core (ver control_unit.sv / figura
// 3 do Plano Mestre). Escrita byte-enabled via bw_i[3:0].
// =============================================================================
module dmem #(
    parameter DEPTH_WORDS = 2048,               // 8 KiB
    parameter [31:0] BASE_ADDR = 32'h1001_0000
) (
    input  logic         clk_i,
    input  logic [31:0]  addr_i,
    input  logic          oe_i,
    input  logic          we_i,
    input  logic [3:0]   bw_i,
    input  logic [31:0]  wdata_i,
    output logic [31:0]  rdata_o
);

    logic [31:0] mem [0:DEPTH_WORDS-1];
    logic [31:0] word_idx;
    logic [31:0] rdata_reg;

    assign word_idx = (addr_i - BASE_ADDR) >> 2;
    assign rdata_o  = rdata_reg;

    initial begin
        for (int i = 0; i < DEPTH_WORDS; i++) mem[i] = 32'd0;
    end

    always_ff @(posedge clk_i) begin
        if (we_i && (word_idx < DEPTH_WORDS)) begin
            if (bw_i[0]) mem[word_idx][7:0]   <= wdata_i[7:0];
            if (bw_i[1]) mem[word_idx][15:8]  <= wdata_i[15:8];
            if (bw_i[2]) mem[word_idx][23:16] <= wdata_i[23:16];
            if (bw_i[3]) mem[word_idx][31:24] <= wdata_i[31:24];
        end
        if (oe_i) begin
            rdata_reg <= (word_idx < DEPTH_WORDS) ? mem[word_idx] : 32'd0;
        end
    end

endmodule
