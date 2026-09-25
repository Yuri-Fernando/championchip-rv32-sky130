# Arquitetura — RV32I_Zmmul_Xicrc

## Sistema

```mermaid
flowchart LR
    TOP["Top-level\nclk_i / rst_i"] -->|clock, reset| CORE
    CORE["RV32I_Zmmul_Xicrc Core\n(multicycle)"] -->|addr, oe, we, bw, wdata| DEC
    DEC["Address Decoder\n(MMIO routing)"] -->|rdata| CORE
    DEC -->|addr, oe| IMEM["IMEM\nROM ate 4 MB\n0x0040_0000"]
    DEC -->|addr, oe, we, bw, wdata| DMEM["DMEM\nSRAM sincrona 8 kB\n0x1001_0000"]
    IMEM -->|rdata| DEC
    DMEM -->|rdata| DEC
```

## FSM (16 estados)

```mermaid
stateDiagram-v2
    [*] --> FETCH
    FETCH --> DECODE
    DECODE --> EXEC_ALU: ALU reg/imm, LUI, AUIPC
    DECODE --> EXEC_BRANCH: branch
    DECODE --> EXEC_JUMP: JAL/JALR
    DECODE --> MEM_ADDR: load/store
    DECODE --> EXEC_MUL: Zmmul
    DECODE --> EXEC_CRC: Xicrc (bloqueado)
    DECODE --> SYSTEM: FENCE/ECALL/EBREAK

    EXEC_ALU --> WB_ALU
    EXEC_JUMP --> WB_ALU
    EXEC_BRANCH --> FETCH
    MEM_ADDR --> MEM_READ: load
    MEM_ADDR --> MEM_WRITE: store
    MEM_READ --> MEM_WAIT
    MEM_WAIT --> WB_MEM
    MEM_WRITE --> FETCH
    EXEC_MUL --> WB_MUL
    EXEC_CRC --> WB_CRC
    SYSTEM --> FETCH

    WB_ALU --> FETCH
    WB_MEM --> FETCH
    WB_MUL --> FETCH
    WB_CRC --> FETCH
```

`MEM_WAIT` existe porque a DMEM é explicitamente síncrona no guia oficial —
a leitura só fica disponível um ciclo depois do `oe`.

## Registradores de estágio

- `pc_reg`, `ir_reg` — write-enable explícito, centralizado em
  `control_unit.sv` (ver `DECISIONS.md` ADR-003 para o bug de PC duplicado
  encontrado e corrigido em JAL/JALR).
- `alu_out_reg`, `mult_out_reg`, `crc_out_reg`, `link_reg` — "free-running"
  (sem enable dedicado), estilo ALUOut/MDR clássico (ADR-002).

## Ver também

- [`../../README.md`](../../README.md) — visão geral e status
- [`../submission/RELATORIO.md`](../submission/RELATORIO.md) — relatório técnico completo
- [`../../notebooks/`](../../notebooks/) — notebooks executáveis (pipeline completo e por etapa)
