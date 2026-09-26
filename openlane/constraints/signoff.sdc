# =============================================================================
# signoff.sdc - Constraints completas de rv32_core (rodada final, ADR-017).
#
# Mesmo conteúdo do SDC padrão do OpenLane 2 (openlane/scripts/base.sdc),
# especializado para o clock clk_i. Todos os valores vêm das variáveis de
# configuração (::env), com os padrões do OpenLane para sky130_fd_sc_hd:
#   MAX_TRANSITION_CONSTRAINT 0,75 ns · MAX_FANOUT_CONSTRAINT 10
#   IO_DELAY_CONSTRAINT 20 % do período · OUTPUT_CAP_LOAD 33,4 fF
#   CLOCK_UNCERTAINTY 0,25 ns · CLOCK_TRANSITION 0,15 ns · derating 5 %
#
# Por que existe: o base.sdc das rodadas baseline/opt30 só criava o clock e os
# atrasos de I/O. Sem set_max_transition/set_max_fanout, o reparo do OpenROAD
# mirava o limite da biblioteca (1,5 ns) e, com os parasitas máximos do corner
# lento, milhares de pinos estouravam; sem set_propagated_clock, a STA pós-CTS
# usava clock ideal (sem skew). base.sdc fica intacto para reproduzir as
# rodadas antigas.
# Nota: `remove_from_collection` NÃO existe no OpenSTA - não usar.
# =============================================================================
set clk_port   clk_i
set clk_period $::env(CLOCK_PERIOD)
set io_delay   [expr {$clk_period * $::env(IO_DELAY_CONSTRAINT) / 100.0}]

create_clock [get_ports $clk_port] -name $clk_port -period $clk_period
set clocks [get_clocks $clk_port]

# limites de projeto: o reparo (repair_design) trabalha contra estes valores
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
}

# entradas sem o clock (lsearch/lreplace porque o OpenSTA não tem remove_from_collection)
set clk_input [get_port $clk_port]
set clk_indx  [lsearch [all_inputs] $clk_input]
set inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx]

set_input_delay  $io_delay -clock $clocks $inputs_wo_clk
set_output_delay $io_delay -clock $clocks [all_outputs]

# ambiente elétrico das portas: quem dirige as entradas e que carga as saídas veem
set drv [split $::env(SYNTH_DRIVING_CELL) "/"]
set_driving_cell -lib_cell [lindex $drv 0] -pin [lindex $drv 1] $inputs_wo_clk
if { [info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set drv [split $::env(SYNTH_CLK_DRIVING_CELL) "/"]
}
set_driving_cell -lib_cell [lindex $drv 0] -pin [lindex $drv 1] $clk_input
set_load [expr {$::env(OUTPUT_CAP_LOAD) / 1000.0}] [all_outputs]

# clock real: incerteza, transição e derating on-chip
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks
set_clock_transition  $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks
set_timing_derate -early [expr {1 - $::env(TIME_DERATING_CONSTRAINT) / 100.0}]
set_timing_derate -late  [expr {1 + $::env(TIME_DERATING_CONSTRAINT) / 100.0}]

# depois da CTS o clock é propagado (skew real); antes dela, ideal
if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
