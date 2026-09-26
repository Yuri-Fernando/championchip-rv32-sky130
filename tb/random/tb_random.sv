// =============================================================================
// tb_random.sv - Teste diferencial randomizado (secao 7.4 do Plano Mestre).
//
// Carrega um programa aleatorio (+PROG=<hex>) gerado por
// tools/iss/gen_random_program.py, executa ate o EBREAK e compara as 96
// primeiras palavras da DMEM (janela de dados + assinatura dos registradores)
// com o resultado do modelo de referencia independente (+EXP=<hex>).
//
// So observa portas e a DMEM (RTL comportamental, fora do core) - nenhuma
// referencia hierarquica ao interior do core. Por isso o MESMO testbench roda
// contra o RTL e contra a netlist gate-level pos-layout (F9).
// =============================================================================
`include "rv32_defs.vh"

module tb_random;
    localparam SIG_WORDS = 96;

    logic clk = 0, rst;
    string prog_file, exp_file;
    logic [31:0] expected [0:SIG_WORDS-1];
    logic [31:0] prog [0:4095];
    int errors = 0;
    int cycles = 0;

    soc_top #(.IMEM_DEPTH_WORDS(4096), .DMEM_DEPTH_WORDS(2048)) dut (
        .clk_i(clk), .rst_i(rst)
    );

`ifndef CLK_HALF
    `define CLK_HALF 5
`endif
    always #(`CLK_HALF) clk = ~clk;

`ifdef SDF_ANNOTATE
    // Atrasos reais pos-layout no core (SDF do OpenLane, por corner); ver
    // scripts/core/gls_sdf.sh. Sem SDF_ANNOTATE o testbench e identico ao de sempre.
    initial begin : sdf_annotate_core
        string sdf_file;
        if ($value$plusargs("SDF=%s", sdf_file)) $sdf_annotate(sdf_file, dut.u_core);
    end
`endif

    initial begin
        if (!$value$plusargs("PROG=%s", prog_file) || !$value$plusargs("EXP=%s", exp_file)) begin
            $display("uso: vvp tb_random.vvp +PROG=<prog.hex> +EXP=<expected.hex>");
            $fatal(1);
        end
        rst = 1;
        #1;
        for (int k = 0; k < 4096; k++) prog[k] = 32'h0000_0013;
        $readmemh(prog_file, prog);
        for (int k = 0; k < 4096; k++) dut.u_imem.mem[k] = prog[k];
        $readmemh(exp_file, expected);

        repeat (2) @(negedge clk);
        rst = 0;

        while (!dut.halt_o && cycles < 60000) begin
            @(negedge clk);
            cycles++;
        end

        if (!dut.halt_o) begin
            $display("[FAIL] %s: timeout (%0d ciclos) sem EBREAK, pc=%h", prog_file, cycles, dut.pc_dbg_o);
            errors++;
        end else begin
            repeat (2) @(negedge clk); // deixa o ultimo store assentar
            for (int w = 0; w < SIG_WORDS; w++) begin
                if (dut.u_dmem.mem[w] !== expected[w]) begin
                    if (errors < 8)
                        $display("[FAIL] %s: DMEM[0x%03h] = %h, esperado %h", prog_file, w * 4, dut.u_dmem.mem[w], expected[w]);
                    errors++;
                end
            end
        end

        if (errors == 0)
            $display("=== tb_random %s: PASS (%0d ciclos) ===", prog_file, cycles);
        else begin
            $display("=== tb_random %s: FAIL (%0d divergencias) ===", prog_file, errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
