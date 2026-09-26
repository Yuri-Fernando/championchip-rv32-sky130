# sky130_timing_models.awk - Ajusta uma COPIA dos modelos temporais da
# sky130_fd_sc_hd para o Icarus Verilog 12 (usada por scripts/core/gls_sdf.sh).
# O PDK original nao e alterado.
#
# 1. O Icarus nao implementa timing checks ($setuphold, $recrem): os sinais
#    "X_delayed" que esses checks deveriam gerar ficariam sem driver (X).
#    Para cada entrada X da celula, adiciona "assign X_delayed = X;" antes do
#    endmodule. Sinais *_delayed gerados pela propria logica da celula (ex.:
#    SCE_gate_delayed no sdlclkp) nao sao tocados. Setup/hold continuam
#    verificados onde pertencem: na STA do OpenLane.
# 2. A celula lpflow_bleeder (nao usada no design) declara um caminho para
#    VPWR, que nao existe na versao sem pinos de alimentacao: linha removida.
#
# Uso: awk -f tools/sky130_timing_models.awk sky130_fd_sc_hd.v > copia.v

/\(SHORT => VPWR\)/ { next }

/^[[:space:]]*module[[:space:]]/ { k = 0; split("", in_port) }

/^[[:space:]]*input[[:space:]]+[A-Za-z0-9_]+[[:space:]]*;/ {
    n = $0
    sub(/^[[:space:]]*input[[:space:]]+/, "", n)
    sub(/[[:space:]]*;.*/, "", n)
    in_port[n] = 1
}

/^[[:space:]]*wire[[:space:]]+[A-Za-z0-9_]+_delayed[[:space:]]*;/ {
    n = $0
    sub(/^[[:space:]]*wire[[:space:]]+/, "", n)
    sub(/_delayed.*/, "", n)
    d[++k] = n
}

/^[[:space:]]*endmodule/ {
    for (j = 1; j <= k; j++)
        if (d[j] in in_port) printf "    assign %s_delayed = %s;\n", d[j], d[j]
    k = 0
}

{ print }
