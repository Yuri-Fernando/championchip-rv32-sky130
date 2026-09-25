# SPEC_GAPS.md — Ambiguidades do guia oficial e resolução adotada

Registro obrigatório (seção 8.1 do Plano Mestre) de toda lacuna do material
oficial e da decisão tomada para não travar o desenvolvimento sem inventar
comportamento não especificado (Artigo IV / princípio P4 do Plano Mestre).

---

## SG-01 — Semântica matemática da extensão Xicrc (CRCB/CRCH/CRCW)

**Status:** 🔴 BLOCKED-XICRC (não fechado)

**Lacuna:** o guia oficial define opcode/funct3/funct7 de CRCB/CRCH/CRCW mas
não especifica: polinômio, valor de inicialização, reflexão de entrada/saída
(refin/refout), xorout, nem a semântica exata de rs1/rs2 (qual é o estado do
CRC e qual é o dado de entrada).

**Decisão:** implementada uma unidade CRC bit-serial genérica e parametrizada
(`rtl/core/crc_unit.sv`), estruturalmente completa e sintetizável, mas com
`crc_blocked_o` permanentemente em alerta e nenhum teste de regressão
dependendo do valor numérico produzido. `tb/unit/tb_crc_unit.sv` valida apenas
propriedades estruturais (determinismo, conectividade), não corretude.

**Para desbloquear:** obter do material oficial da competição (firmware de
referência, testbench do ChipInventor, ou documentação adicional) pelo menos
3 vetores golden por instrução (CRCB/CRCH/CRCW), incluindo estado inicial e
resultado esperado (critério do Plano Mestre, seção 5.4). Substituir os
parâmetros placeholder do `crc_unit` e criar `tb/isa/tb_xicrc_golden.sv`.

**Impacto na submissão:** ISA fecha em 44/47 (RV32I 40/40 + Zmmul 4/4).
Xicrc permanece arquiteturalmente pronto para integração imediata assim que
a especificação chegar.

---

## SG-02 — Estratégia física de memória (IMEM até 4 MB / DMEM 8 kB)

**Status:** 🟡 Mitigado para simulação; pendente para fechamento físico

**Lacuna:** o guia descreve capacidade lógica de IMEM até 4 MB (base
0x0040_0000) e DMEM até 8 kB (base 0x1001_0000), mas não especifica a
macro/template físico real disponibilizado pela organização.

**Decisão:** `rtl/memory/imem.sv` e `rtl/memory/dmem.sv` são modelos
comportamentais parametrizados (default 16 KiB / 8 KiB) usados em `soc_top`
para toda a verificação funcional. `rtl/top/chip_top.sv` é o top físico e
deve trocar esses modelos pela macro/template oficial (SRAM/ROM SKY130 real)
antes do fechamento físico definitivo — sintetizar 4 MB em flip-flops
inviabilizaria área (risco R-02 do Plano Mestre).

**Para desbloquear:** obter o template/macro de memória física da
organização (ChipInventor RVBL-2) ou confirmar que a submissão aceita
memória sintetizada em macro genérica do OpenLane/SKY130 (ex. OpenRAM).

---

## SG-03 — Pinout físico (chip_top): GPIO/serial

**Status:** 🟡 Reservado, não implementado (tie-off seguro)

**Lacuna:** o guia menciona 12 pinos (8 GPIO, 2 serial, clock e reset) mas
não detalha endereçamento MMIO, protocolo serial ou direção/mux dos GPIO
(risco R10 do Plano Mestre — "risco de escopo").

**Decisão:** `rtl/top/chip_top.sv` expõe `gpio_io[7:0]`, `uart_tx_o`,
`uart_rx_i` na interface (nomes/posição já reservados) mas com tie-off
seguro (`gpio_io=8'bz`, `uart_tx_o=0`), sem lógica funcional inventada.

**Para desbloquear:** confirmar mapa de endereço MMIO e protocolo serial
junto ao material oficial/template da competição.

---

## SG-04 — Polaridade do reset

**Status:** 🟡 Assumido ativo-alto (padrão OpenLane/SKY130); não confirmado

**Decisão:** todo o RTL assume `rst_i` ativo-alto, síncrono. Confirmar contra
o template oficial antes do freeze físico (seção 3.3 do Plano Mestre).

---

## SG-05 — Firmware oficial da competição

**Status:** 🔴 Não disponível neste repositório

**Lacuna:** não há, nesta pasta de projeto, repositório/template oficial da
ChampionCHIP nem firmware de referência — apenas o guia em PDF e o Plano
Mestre de planejamento gerado a partir dele. O protocolo de execução do
Plano Mestre (seção 13) pede que a primeira fonte de verdade sejam os
"arquivos oficiais da competição existentes no repositório", que não estão
presentes.

**Decisão:** `firmware/smoke/` contém um firmware de smoke-test autoral,
cobrindo as 44 instruções fechadas, usado como evidência de execução
end-to-end (fetch→decode→execute→writeback→load/store) na ausência do
firmware oficial. Isso **não substitui** o requisito R7 (firmware oficial)
do guia.

**Para desbloquear:** obter do organizador o firmware/template oficial da
Fase 2 e o repositório-base da competição, e então rodar F6 conforme
planejado (seção 9 do Plano Mestre).
