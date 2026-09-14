// =============================================================================
// tb_crc_unit.sv - Teste ESTRUTURAL apenas (BLOCKED-XICRC, ver crc_unit.sv e
// SPEC_GAPS.md SG-01). Sem vetor oficial, NAO valida valores numericos de
// CRC - apenas: (1) crc_blocked_o permanece em alerta, (2) a unidade e
// deterministica (mesma entrada -> mesma saida), (3) responde aos 3 funct3
// (CRCB/CRCH/CRCW) com valores potencialmente distintos (sinal de que o
// datapath estrutural esta conectado). Assim que o vetor oficial existir,
// substituir por tb_isa/tb_xicrc_golden.sv com os valores reais.
// =============================================================================
`include "rv32_defs.vh"
`include "tb_utils.vh"

module tb_crc_unit;
    logic [31:0] rs1, rs2, result;
    logic [2:0]  f3;
    logic         blocked;
    logic [31:0] r1, r_b, r_h, r_w;
    int errors = 0;

    crc_unit dut (.rs1_i(rs1), .rs2_i(rs2), .funct3_i(f3), .result_o(result), .crc_blocked_o(blocked));

    initial begin
        rs1 = 32'hFFFF_FFFF; rs2 = 32'h0000_00A5; f3 = `F3_CRCB; #1;
        `CHECK_TRUE("crc_blocked_o permanece ativo (SG-01)", blocked);

        // Determinismo: mesma entrada -> mesma saida
        r1 = result;
        rs1 = 32'hFFFF_FFFF; rs2 = 32'h0000_00A5; f3 = `F3_CRCB; #1;
        `CHECK_EQ("determinismo (mesma entrada)", result, r1);

        // funct3 distintos tendem a produzir resultados distintos (sanity
        // estrutural - NAO e criterio de correcao matematica)
        f3 = `F3_CRCB; #1; r_b = result;
        f3 = `F3_CRCH; #1; r_h = result;
        f3 = `F3_CRCW; #1; r_w = result;
        `CHECK_TRUE("CRCB/CRCH/CRCW nao sao todos identicos (datapath conectado)",
                    !(r_b == r_h && r_h == r_w));

        `TB_FINISH("tb_crc_unit (estrutural, NAO substitui vetor oficial)");
    end
endmodule
