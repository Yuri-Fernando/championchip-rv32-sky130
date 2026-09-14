// =============================================================================
// imem.sv - Modelo de instruction memory (ROM) PARA SIMULACAO/INTEGRACAO.
//
// O guia oficial descreve capacidade logica de ate 4 MB (base 0x0040_0000),
// mas nao especifica a macro/template fisico real. Sintetizar 4 MB como
// flip-flops inviabilizaria area no SKY130 (risco R-02 do Plano Mestre).
// Por isso este modelo e dimensionado por parametro (default 16 KiB, o
// suficiente para o firmware de smoke-test) e o top FISICO (chip_top) deve
// substituir este bloco pela macro/template oficial da organizacao antes do
// fechamento fisico definitivo - ver SPEC_GAPS.md item SG-02.
//
// Leitura combinacional (assincrona): o guia so exige estado de espera
// dedicado para a DMEM, que e explicitamente sincrona.
// =============================================================================
module imem #(
    parameter DEPTH_WORDS = 4096,               // 16 KiB (16'd4096 * 4 bytes)
    parameter [31:0] BASE_ADDR = 32'h0040_0000,
    parameter HEXFILE = ""                        // caminho $readmemh (build)
) (
    input  logic [31:0] addr_i,
    input  logic          oe_i,
    output logic [31:0]  rdata_o
);

    logic [31:0] mem [0:DEPTH_WORDS-1];
    logic [31:0] word_idx;

    assign word_idx = (addr_i - BASE_ADDR) >> 2;

    initial begin
        for (int i = 0; i < DEPTH_WORDS; i++) mem[i] = 32'h0000_0013; // NOP (ADDI x0,x0,0)
        if (HEXFILE != "") $readmemh(HEXFILE, mem);
    end

    assign rdata_o = (oe_i && (word_idx < DEPTH_WORDS)) ? mem[word_idx] : 32'd0;

endmodule
