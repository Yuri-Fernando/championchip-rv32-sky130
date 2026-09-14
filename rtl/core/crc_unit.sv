// =============================================================================
// crc_unit.sv - Unidade CRCB/CRCH/CRCW (extensao custom Xicrc).
//
// *** STATUS: BLOCKED-XICRC ***  (ver SPEC_GAPS.md item SG-01 e DECISIONS.md)
//
// O guia oficial da Fase 2 define opcode/funct3/funct7 de CRCB/CRCH/CRCW mas
// NAO fecha a semantica matematica: falta polinomio, valor de init, reflexao
// de entrada/saida (refin/refout), xorout e a interpretacao exata de rs1/rs2
// (qual e o estado do CRC e qual e o dado de entrada). Por regra do Plano
// Mestre (secao 1, "Ponto critico de especificacao" e regra 12 do protocolo
// de execucao), essa lacuna NAO deve ser preenchida por suposicao.
//
// Esta unidade implementa um motor de CRC bit-serial GENERICO e
// PARAMETRIZADO (largura, polinomio, init, refin/refout, xorout), estrutural
// e sintetizavel, para que a integracao final baste trocar os parametros
// quando o firmware/testbench/material oficial da competicao revelar o
// comportamento correto. Ate la:
//   - Os resultados NAO devem ser tratados como corretos.
//   - crc_blocked_o fica permanentemente em 1'b1 (grep-avel por scripts).
//   - Nenhum teste de regressao pode depender do valor numerico produzido
//     aqui sem um vetor golden oficial (ver TEST_MATRIX.csv, linhas 45-47).
//
// Convencao assumida (NAO CONFIRMADA): rs1_i = estado atual do CRC,
// rs2_i = dado de entrada (byte/half/word nos bits menos significativos,
// little-endian), resultado = novo estado do CRC.
// =============================================================================
`include "rv32_defs.vh"

module crc_unit #(
    parameter CRC_WIDTH   = 32,
    parameter [31:0] POLY = 32'h04C11DB7, // placeholder (CRC-32/MPEG-2 raw poly) - NAO OFICIAL
    parameter [31:0] INIT = 32'hFFFFFFFF, // placeholder - NAO OFICIAL
    parameter        REFIN  = 1'b0,       // placeholder - NAO OFICIAL
    parameter        REFOUT = 1'b0,       // placeholder - NAO OFICIAL
    parameter [31:0] XOROUT = 32'h00000000 // placeholder - NAO OFICIAL
) (
    input  logic [31:0] rs1_i,      // estado do CRC (assumido)
    input  logic [31:0] rs2_i,      // dado de entrada (assumido)
    input  logic [2:0]  funct3_i,   // F3_CRCB/F3_CRCH/F3_CRCW
    output logic [31:0] result_o,
    output logic         crc_blocked_o
);

    assign crc_blocked_o = 1'b1; // NUNCA remover sem vetor oficial fechado (SG-01)

    function automatic [7:0] bitrev8(input [7:0] din);
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1) bitrev8[k] = din[7-k];
        end
    endfunction

    function automatic [31:0] bitrev32(input [31:0] din);
        integer k;
        begin
            for (k = 0; k < 32; k = k + 1) bitrev32[k] = din[31-k];
        end
    endfunction

    function automatic [31:0] crc_update(input [31:0] crc_in, input [31:0] data_in, input integer nbytes);
        reg [31:0] crc;
        reg [7:0]  byte_in;
        integer i, b;
        begin
            crc = crc_in;
            for (b = 0; b < nbytes; b = b + 1) begin
                byte_in = REFIN ? bitrev8(data_in[b*8 +: 8]) : data_in[b*8 +: 8];
                crc = crc ^ ({24'd0, byte_in} << (CRC_WIDTH - 8));
                for (i = 0; i < 8; i = i + 1) begin
                    if (crc[CRC_WIDTH-1])
                        crc = (crc << 1) ^ POLY;
                    else
                        crc = crc << 1;
                end
            end
            crc_update = (REFOUT ? bitrev32(crc) : crc) ^ XOROUT;
        end
    endfunction

    always_comb begin
        case (funct3_i)
            `F3_CRCB: result_o = crc_update(rs1_i, rs2_i, 1);
            `F3_CRCH: result_o = crc_update(rs1_i, rs2_i, 2);
            `F3_CRCW: result_o = crc_update(rs1_i, rs2_i, 4);
            default:  result_o = rs1_i;
        endcase
    end

endmodule
