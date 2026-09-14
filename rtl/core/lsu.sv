// =============================================================================
// lsu.sv - Load/Store Unit combinacional. Formata dado de store (alinhamento +
// mascara de byte-write) e formata dado de load (sign/zero extend), conforme
// tabela 5.5 do Plano Mestre. DMEM e um array de palavras de 32 bits; o
// alinhamento sub-word e resolvido aqui a partir de addr_i[1:0].
//
// O guia nao define trap de misalignment; por regra de projeto (secao 5.5),
// acessos desalinhados apenas geram o sinal misaligned_o para uso em
// assertion/simulacao - nenhum handler de trap e sintetizado nesta fase.
// =============================================================================
`include "rv32_defs.vh"

module lsu (
    input  logic [1:0]  addr_lsb_i,   // addr_i[1:0]
    input  logic [2:0]  funct3_i,
    input  logic         is_store_i,
    input  logic [31:0]  store_data_i, // rs2 bruto
    input  logic [31:0]  mem_rdata_i,  // palavra lida da DMEM
    output logic [31:0]  mem_wdata_o,
    output logic [3:0]   bw_o,
    output logic [31:0]  load_data_o,
    output logic          misaligned_o
);

    logic [15:0] half_sel;
    logic [7:0]  byte_sel;

    // ---- Selecao de sub-campo para load ---------------------------------
    always_comb begin
        byte_sel = mem_rdata_i[addr_lsb_i*8 +: 8];
        half_sel = addr_lsb_i[1] ? mem_rdata_i[31:16] : mem_rdata_i[15:0];
    end

    // ---- Formatacao do load -----------------------------------------------
    always_comb begin
        case (funct3_i)
            `F3_LB:  load_data_o = {{24{byte_sel[7]}}, byte_sel};
            `F3_LBU: load_data_o = {24'd0, byte_sel};
            `F3_LH:  load_data_o = {{16{half_sel[15]}}, half_sel};
            `F3_LHU: load_data_o = {16'd0, half_sel};
            `F3_LW:  load_data_o = mem_rdata_i;
            default: load_data_o = mem_rdata_i;
        endcase
    end

    // ---- Formatacao do store (dado deslocado + mascara de byte) -----------
    always_comb begin
        case (funct3_i)
            `F3_SB: begin
                mem_wdata_o = {4{store_data_i[7:0]}};
                bw_o        = 4'b0001 << addr_lsb_i;
            end
            `F3_SH: begin
                mem_wdata_o = {2{store_data_i[15:0]}};
                bw_o        = addr_lsb_i[1] ? 4'b1100 : 4'b0011;
            end
            `F3_SW: begin
                mem_wdata_o = store_data_i;
                bw_o        = 4'b1111;
            end
            default: begin
                mem_wdata_o = store_data_i;
                bw_o        = 4'b0000;
            end
        endcase
        if (!is_store_i) bw_o = 4'b0000;
    end

    // ---- Deteccao de desalinhamento (somente flag; sem trap) --------------
    always_comb begin
        // F3_LH==F3_SH (001) e F3_LW==F3_SW (010): os encodings de
        // load/store compartilham funct3, entao um unico ramo cobre os 4.
        case (funct3_i)
            `F3_LH, `F3_LW: misaligned_o =
                (funct3_i == `F3_LW) ? (addr_lsb_i != 2'b00) : addr_lsb_i[0];
            default: misaligned_o = 1'b0;
        endcase
    end

endmodule
