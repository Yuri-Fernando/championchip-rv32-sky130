// =============================================================================
// tb_firmware_smoke.sv - Simula o firmware de smoke-test REAL (compilado via
// toolchain RISC-V, nao instrucoes hand-encoded) sobre soc_top, carregando
// firmware/build/smoke_test.hex via $readmemh. Verifica a assinatura gravada
// em result_addr (DMEM): PASS_SIG=0x600DC0DE ou FAIL_SIG=0xBAD00BAD + numero
// do teste que falhou (ver firmware/smoke/smoke_test.S).
//
// Endereco de result_addr no DMEM depende do linker script; e resolvido em
// tempo de simulacao lendo firmware/build/smoke_test.map (offset fixo
// documentado abaixo, conferido apos o build).
// =============================================================================
`include "rv32_defs.vh"

module tb_firmware_smoke;
    logic clk = 0, rst;
    int errors = 0;

    // offset de result_addr dentro da DMEM (ver firmware/build/smoke_test.map);
    // atualizado automaticamente por scripts/run_firmware_sim.sh via +define.
`ifndef RESULT_WORD_OFFSET
    `define RESULT_WORD_OFFSET 8
`endif

    soc_top #(
        .IMEM_DEPTH_WORDS(4096),
        .DMEM_DEPTH_WORDS(2048),
        .IMEM_HEXFILE("firmware/build/smoke_test.hex")
    ) dut (
        .clk_i(clk), .rst_i(rst)
    );

    always #5 clk = ~clk;

    // Waveform para evidencia/relatorio (+vcd): so o escopo do core (nivel 1),
    // mantendo o arquivo pequeno. Nao usar na simulacao gate-level (a netlist
    // plana tem dezenas de milhares de nets nesse escopo).
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("docs/evidence/waveforms/firmware_smoke.vcd");
            $dumpvars(1, dut.u_core);
        end
    end

    initial begin
        logic [31:0] sig, testnum;
        rst = 1; repeat (2) @(negedge clk); rst = 0;

        for (int cyc = 0; cyc < 5000 && !dut.halt_o; cyc = cyc + 1) @(negedge clk);

        if (!dut.halt_o) begin
            $display("[FAIL] firmware nao atingiu EBREAK dentro do orcamento de ciclos");
            errors = errors + 1;
        end else begin
            sig     = dut.u_dmem.mem[`RESULT_WORD_OFFSET];
            testnum = dut.u_dmem.mem[`RESULT_WORD_OFFSET + 1];
            $display("[INFO] result_sig=%h testnum=%0d pc_final=%h", sig, testnum, dut.pc_dbg_o);
            if (sig == 32'h600D_C0DE) begin
                $display("[ pass ] firmware smoke-test PASS (%0d blocos)", testnum);
            end else begin
                $display("[FAIL] firmware smoke-test FAIL no bloco %0d (sig=%h)", testnum, sig);
                errors = errors + 1;
            end
        end

        if (errors == 0) $display("=== tb_firmware_smoke: PASS ===");
        else begin
            $display("=== tb_firmware_smoke: FAIL (%0d erros) ===", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
