// =============================================================================
// tb_utils.vh - Macros minimas de checagem para testbenches unitarios.
// Convencao: cada testbench declara `int errors = 0;` e usa `CHECK_EQ`.
// Ao final, `TB_FINISH` imprime PASS/FAIL e define o exit code (via $fatal)
// para uso em scripts/run_unit_tests.sh (regressao).
// =============================================================================
`ifndef TB_UTILS_VH
`define TB_UTILS_VH

`define CHECK_EQ(desc, got, exp) \
    do begin \
        if ((got) !== (exp)) begin \
            $display("[FAIL] %s | got=0x%0h exp=0x%0h (t=%0t)", desc, got, exp, $time); \
            errors = errors + 1; \
        end else begin \
            $display("[ pass ] %s", desc); \
        end \
    end while (0)

`define CHECK_TRUE(desc, cond) \
    do begin \
        if (!(cond)) begin \
            $display("[FAIL] %s (t=%0t)", desc, $time); \
            errors = errors + 1; \
        end else begin \
            $display("[ pass ] %s", desc); \
        end \
    end while (0)

`define TB_FINISH(tbname) \
    do begin \
        if (errors == 0) begin \
            $display("=== %s: PASS (0 erros) ===", tbname); \
        end else begin \
            $display("=== %s: FAIL (%0d erros) ===", tbname, errors); \
            $fatal(1); \
        end \
        $finish; \
    end while (0)

`endif
