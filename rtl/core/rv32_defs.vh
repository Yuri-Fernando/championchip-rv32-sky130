// =============================================================================
// rv32_defs.vh - Constantes de opcode/funct3/funct7 e ALU-op para o
// ChampionCHIP RV32I_Zmmul_Xicrc core.
//
// Fonte de verdade: Plano_Mestre_ChampionCHIP_Fase2 secao 4.1 (Encodings
// criticos), cruzado com a especificacao oficial RISC-V RV32I / Zmmul.
// NAO alterar sem atualizar DECISIONS.md.
// =============================================================================
`ifndef RV32_DEFS_VH
`define RV32_DEFS_VH

// ---- Opcodes (instr[6:0]) --------------------------------------------------
`define OPC_ALU_REG   7'b0110011 // R-type: ALU reg-reg, Zmmul (funct7=0000001), Xicrc (funct7=1000000)
`define OPC_ALU_IMM   7'b0010011 // I-type: ALU imm
`define OPC_LOAD      7'b0000011
`define OPC_STORE     7'b0100011
`define OPC_BRANCH    7'b1100011
`define OPC_JAL       7'b1101111
`define OPC_JALR      7'b1100111
`define OPC_LUI       7'b0110111
`define OPC_AUIPC     7'b0010111
`define OPC_FENCE     7'b0001111
`define OPC_SYSTEM    7'b1110011 // ECALL/EBREAK

// ---- funct7 dentro de OPC_ALU_REG -----------------------------------------
`define F7_ALU_BASE   7'b0000000 // ADD/SLL/SLT/SLTU/XOR/SRL/OR/AND
`define F7_ALU_ALT    7'b0100000 // SUB/SRA
`define F7_ZMMUL      7'b0000001 // MUL/MULH/MULHSU/MULHU
`define F7_XICRC      7'b1000000 // CRCB/CRCH/CRCW

// ---- funct3 (ALU reg/imm) --------------------------------------------------
`define F3_ADD_SUB  3'b000
`define F3_SLL      3'b001
`define F3_SLT      3'b010
`define F3_SLTU     3'b011
`define F3_XOR      3'b100
`define F3_SRL_SRA  3'b101
`define F3_OR       3'b110
`define F3_AND      3'b111

// ---- funct3 (Zmmul) --------------------------------------------------------
`define F3_MUL      3'b000
`define F3_MULH     3'b001
`define F3_MULHSU   3'b010
`define F3_MULHU    3'b011

// ---- funct3 (Xicrc, segundo guia oficial) ----------------------------------
`define F3_CRCB     3'b000
`define F3_CRCH     3'b001
`define F3_CRCW     3'b010

// ---- funct3 (Load) ----------------------------------------------------------
`define F3_LB   3'b000
`define F3_LH   3'b001
`define F3_LW   3'b010
`define F3_LBU  3'b100
`define F3_LHU  3'b101

// ---- funct3 (Store) ----------------------------------------------------------
`define F3_SB   3'b000
`define F3_SH   3'b001
`define F3_SW   3'b010

// ---- funct3 (Branch) --------------------------------------------------------
`define F3_BEQ   3'b000
`define F3_BNE   3'b001
`define F3_BLT   3'b100
`define F3_BGE   3'b101
`define F3_BLTU  3'b110
`define F3_BGEU  3'b111

// ---- funct3 (System) --------------------------------------------------------
`define F3_SYS   3'b000
`define IMM12_ECALL  12'h000
`define IMM12_EBREAK 12'h001

// ---- ALU op select (interno, nao normativo do guia) ------------------------
`define ALU_ADD    4'd0
`define ALU_SUB    4'd1
`define ALU_SLL    4'd2
`define ALU_SLT    4'd3
`define ALU_SLTU   4'd4
`define ALU_XOR    4'd5
`define ALU_SRL    4'd6
`define ALU_SRA    4'd7
`define ALU_OR     4'd8
`define ALU_AND    4'd9
`define ALU_PASSB  4'd10 // LUI: resultado = operando B (imediato)

// ---- Tipos de imediato -------------------------------------------------------
`define IMM_I  3'd0
`define IMM_S  3'd1
`define IMM_B  3'd2
`define IMM_U  3'd3
`define IMM_J  3'd4

// ---- Mapa de memoria (secao 5.6 do Plano Mestre; confirmar antes do freeze) -
`define IMEM_BASE 32'h0040_0000
`define IMEM_END  32'h007F_FFFF
`define DMEM_BASE 32'h1001_0000
`define DMEM_END  32'h1001_1FFF
`define PC_RESET  32'h0040_0000

`endif // RV32_DEFS_VH
