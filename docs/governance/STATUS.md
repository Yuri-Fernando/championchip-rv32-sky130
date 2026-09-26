# STATUS.md

Estado ao final da sessão de 26/09/2026 (item 16 do protocolo de execução do
Plano Mestre). Visão completa: [`versioning/REGISTRO_MESTRE.md`](../../versioning/REGISTRO_MESTRE.md).

## Feito

- F0–F4: especificação congelada com 5 lacunas documentadas; 14 módulos RTL;
  RV32I 40/40 com teste dirigido; dois bugs reais de PC corrigidos.
- F5: Zmmul 4/4; Xicrc estrutural e bloqueada (SG-01).
- F6: firmware autoral PASS no RTL e na netlist gate-level; oficial indisponível (SG-05).
- F7: baseline 40 ns — DRC 0, LVS 0, timing fechado.
- F8: 30 ns (33,3 MHz) — DRC 0, LVS 0, timing fechado nos 9 corners com SDC de
  sign-off completo; nenhum pino acima do limite de slew da biblioteca
  (diodos em massa removidos, ADR-016; SDC completo, ADR-017).
- F9: gate-level — firmware + 10 programas aleatórios nas quatro netlists.
- Verificação avançada: modelo de referência independente, 20 programas
  aleatórios idênticos, mutation score 13/13.
- Infraestrutura: scripts portáveis, CI, relatórios, dashboard, notebooks,
  apresentação e roteiro do vídeo.

## Testes (evidência real)

14/14 suítes de regressão · 13/13 mutantes · gate-level PASS (baseline, opt30, sem_diodos e final).
Logs em `docs/evidence/logs/`, resumos em `reports/`.

## Pendências / blockers

1. **SG-01** — parâmetros do CRC (Xicrc): bloqueia 47/47.
2. **SG-02** — macro física das memórias: bloqueia o top físico completo.
3. **SG-03 / SG-04** — pinagem e polaridade do reset: a confirmar.
4. **SG-05** — firmware oficial: bloqueia o requisito R7 na forma oficial.
5. **KI-10 / KI-11** — na rodada final: 263 pinos acima da meta de slew de 0,75 ns, 74 de cap e 24 de antena (não afetam timing nem DRC/LVS).
6. **Vídeo** — apresentação e roteiro prontos (material local, fora do repositório); falta gravar.

## Próximo comando exato

```bash
# reproduzir tudo que roda em minutos:
make lint test mutation gls dashboard
# quando chegar material oficial: atualizar crc_unit.sv (SG-01) e rodar
make test mutation openlane-final gls dashboard
```
