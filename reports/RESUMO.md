# Resumo de evidencias (gerado em 2026-09-26 por tools/build_reports.py)

- ISA: **44/47** instrucoes fechadas
- Regressao: **14/14** suites PASS
- Teste de mutacao: **13/13** mutantes detectados
- Gate-level: firmware=PASS, random 10 programas=PASS
- Gate-level com SDF (atrasos reais): max_ss_100C_1v60/firmware=PASS, max_ss_100C_1v60/random 3 programas=PASS, min_ff_n40C_1v95/firmware=PASS, min_ff_n40C_1v95/random 3 programas=PASS, nom_tt_025C_1v80/firmware=PASS, nom_tt_025C_1v80/random 3 programas=PASS, max_ss_100C_1v60/controle negativo 10 ns (deve falhar)=FALHOU COMO ESPERADO

| run | SDC | clock | folga setup (pior corner) | Fmax est. | DRC | LVS | antena | slew (limite) | cap | area std-cell | potencia |
|---|---|---|---|---|---|---|---|---|---|---|---|
| baseline | base.sdc | 40 ns (25.0 MHz) | 11.57 ns | 35.2 MHz | 0 | 0 | 2 | 7486 (1.5 ns) | 143 | 259760 um2 | 31.9 mW |
| opt30 | base.sdc | 30 ns (33.3 MHz) | 1.14 ns | 34.7 MHz | 0 | 0 | 2 | 7620 (1.5 ns) | 140 | 259752 um2 | 42.6 mW |
| sem_diodos | base.sdc | 30 ns (33.3 MHz) | 2.64 ns | 36.6 MHz | 0 | 0 | 19 | 3139 (1.5 ns) | 111 | 220016 um2 | 42.0 mW |
| final | signoff.sdc | 30 ns (33.3 MHz) | 0.09 ns | 33.4 MHz | 0 | 0 | 24 | 263 (0.75 ns) | 74 | 245867 um2 | 44.5 mW |

Rodadas com base.sdc usam clock ideal, sem derating/incerteza e o limite de slew da biblioteca (1,5 ns);
signoff.sdc tem as restricoes completas do OpenLane (limite 0,75 ns, clock propagado, derating 5 %). Ver ADR-017.

## Varredura (limite de frequencia e densidade, SDC de sign-off)

| rodada | clock | utilizacao | folga setup | caminhos violando | DRC | LVS | antena | area do die |
|---|---|---|---|---|---|---|---|---|
| final | 30 ns (33.3 MHz) | 35 % | 0.09 ns | 0 | 0 | 0 | 24 | 681917 um2 |
| sweep_28ns | 28 ns (35.7 MHz) | 35 % | -1.35 ns | 13 | 0 | 0 | 22 | 681917 um2 |
| sweep_u45 | 30 ns (33.3 MHz) | 45 % | -0.82 ns | 3 | 0 | 0 | 38 | 533200 um2 |
