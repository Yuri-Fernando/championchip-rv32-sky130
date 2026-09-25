# =============================================================================
# base.sdc - Constraints de timing de rv32_core.
# O periodo vem de CLOCK_PERIOD da config (OpenLane exporta as variaveis de
# configuracao como ::env para o interpretador Tcl do OpenROAD/OpenSTA), para
# que o sweep fisico (F8) altere apenas o config.json.
# Delays de I/O = 10% do periodo (convencao do base.sdc padrao do OpenLane).
# Nota: `remove_from_collection` NAO existe no OpenSTA - nao usar.
# =============================================================================
set clk_period $::env(CLOCK_PERIOD)
set io_delay   [expr {$clk_period * 0.1}]

create_clock [get_ports clk_i] -name clk_i -period $clk_period
set_input_delay  $io_delay -clock clk_i [all_inputs]
set_output_delay $io_delay -clock clk_i [all_outputs]
