# =============================================================================
# base.sdc - Constraints de timing baseline para rv32_core (fase F7,
# OpenLane baseline). Clock relaxado (25 MHz) na primeira rodada para
# priorizar robustez/completude do flow sobre recorde de area/frequencia
# (secao 10.1 do Plano Mestre - "meta e robustez e completude do flow").
# =============================================================================
create_clock [get_ports clk_i] -name clk_i -period 40
set_input_delay 4 -clock clk_i [remove_from_collection [all_inputs] [get_ports clk_i]]
set_output_delay 4 -clock clk_i [all_outputs]
