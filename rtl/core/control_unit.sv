// =============================================================================
// control_unit.sv - Decode combinacional + FSM multicycle (Figura 3 do Plano
// Mestre). Gera apenas SELECTS/ENABLES; os registradores de estagio/resultado
// (PC, IR, ALUOut, MultOut, CrcOut) vivem em rv32_core.sv, que e quem "monta"
// o datapath com esses sinais (regra da secao 5: control_unit nao deve conter
// caminho de dados).
//
// Decisao de projeto (ver DECISIONS.md): os selects de operando da ALU
// (alu_a_sel_pc_o / alu_b_sel_imm_o / alu_sel_o) sao funcao apenas do OPCODE
// (estaveis durante toda a instrucao, pois IR so muda em FETCH), exceto o
// caso especial do calculo de alvo de branch em S_EXEC_BRANCH. Isso permite
// que ALUOut seja um registrador "free-running" classico (sem write-enable
// dedicado), tal como ALUOut/MDR no multicycle MIPS de Patterson&Hennessy,
// reduzindo logica de controle e superficie de bug (principio P1/P6).
// =============================================================================
`include "rv32_defs.vh"

module control_unit (
    input  logic         clk_i,
    input  logic         rst_i,
    input  logic [31:0]  instr_i,        // = ir_reg (estavel durante a instrucao)
    input  logic          branch_taken_i, // vindo do branch_cmp

    output logic [3:0]   state_o,

    // PC
    output logic          pc_we_o,
    output logic          pc_sel_target_o, // 0 = PC+4 ; 1 = alvo (branch/jump, = alu_result_o)

    // IR
    output logic          ir_we_o,

    // ALU
    output logic [3:0]   alu_sel_o,
    output logic          alu_a_sel_pc_o,  // 1 = operando A = PC
    output logic          alu_b_sel_imm_o, // 1 = operando B = imediato ; 0 = rs2

    // Imediato
    output logic [2:0]   imm_type_o,

    // Regfile / writeback
    output logic          reg_we_o,
    output logic [1:0]   rd_sel_o,        // 00=ALUOut 01=load_data 10=MultOut 11=CrcOut
    output logic          rd_sel_pc4_o,    // 1 = link (PC+4), prioridade sobre rd_sel_o (JAL/JALR)

    // Memoria de dados / endereco
    output logic          mem_oe_o,
    output logic          mem_we_o,
    output logic          mem_addr_sel_alu_o, // 1 = endereco = ALUOut ; 0 = endereco = PC
    output logic          is_store_o,

    // Diagnostico (nao sintetiza trap real)
    output logic          halt_o,
    output logic          illegal_o
);

    // ---- Estados da FSM -----------------------------------------------------
    localparam S_FETCH       = 4'd0;
    localparam S_DECODE      = 4'd1;
    localparam S_EXEC_ALU    = 4'd2;
    localparam S_EXEC_BRANCH = 4'd3;
    localparam S_EXEC_JUMP   = 4'd4;
    localparam S_MEM_ADDR    = 4'd5;
    localparam S_MEM_READ    = 4'd6;
    localparam S_MEM_WAIT    = 4'd7;
    localparam S_MEM_WRITE   = 4'd8;
    localparam S_EXEC_MUL    = 4'd9;
    localparam S_EXEC_CRC    = 4'd10;
    localparam S_SYSTEM      = 4'd11;
    localparam S_WB_ALU      = 4'd12;
    localparam S_WB_MEM      = 4'd13;
    localparam S_WB_MUL      = 4'd14;
    localparam S_WB_CRC      = 4'd15;

    logic [3:0] state, state_n;

    // ---- Campos decodificados -------------------------------------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    logic [4:0] rd_addr;

    assign opcode  = instr_i[6:0];
    assign funct3  = instr_i[14:12];
    assign funct7  = instr_i[31:25];
    assign rd_addr = instr_i[11:7];

    // ---- Classes de instrucao (combinacional, nao depende do estado) -----
    logic is_alu_reg, is_alu_imm, is_load, is_store, is_branch, is_jal, is_jalr;
    logic is_lui, is_auipc, is_fence, is_system, is_zmmul, is_xicrc;
    logic is_ecall, is_ebreak;

    assign is_alu_reg = (opcode == `OPC_ALU_REG) && (funct7 == `F7_ALU_BASE || funct7 == `F7_ALU_ALT);
    assign is_zmmul    = (opcode == `OPC_ALU_REG) && (funct7 == `F7_ZMMUL);
    assign is_xicrc     = (opcode == `OPC_ALU_REG) && (funct7 == `F7_XICRC);
    assign is_alu_imm  = (opcode == `OPC_ALU_IMM);
    assign is_load      = (opcode == `OPC_LOAD);
    assign is_store     = (opcode == `OPC_STORE);
    assign is_branch    = (opcode == `OPC_BRANCH);
    assign is_jal        = (opcode == `OPC_JAL);
    assign is_jalr       = (opcode == `OPC_JALR);
    assign is_lui         = (opcode == `OPC_LUI);
    assign is_auipc      = (opcode == `OPC_AUIPC);
    assign is_fence      = (opcode == `OPC_FENCE);
    assign is_system     = (opcode == `OPC_SYSTEM);
    assign is_ecall      = is_system && (instr_i[31:20] == `IMM12_ECALL) && (funct3 == `F3_SYS);
    assign is_ebreak     = is_system && (instr_i[31:20] == `IMM12_EBREAK) && (funct3 == `F3_SYS);

    assign is_store_o = is_store;

    assign illegal_o = !(is_alu_reg || is_zmmul || is_xicrc || is_alu_imm || is_load ||
                          is_store || is_branch || is_jal || is_jalr || is_lui ||
                          is_auipc || is_fence || is_system);

    assign halt_o = (state == S_SYSTEM) && (is_ecall || is_ebreak);

    // ---- Registrador de estado --------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) state <= S_FETCH;
        else       state <= state_n;
    end
    assign state_o = state;

    // ---- Proximo estado -----------------------------------------------------
    always_comb begin
        case (state)
            S_FETCH:       state_n = S_DECODE;
            S_DECODE: begin
                if (is_alu_reg || is_alu_imm || is_lui || is_auipc) state_n = S_EXEC_ALU;
                else if (is_zmmul)                                    state_n = S_EXEC_MUL;
                else if (is_xicrc)                                     state_n = S_EXEC_CRC;
                else if (is_load || is_store)                         state_n = S_MEM_ADDR;
                else if (is_branch)                                    state_n = S_EXEC_BRANCH;
                else if (is_jal || is_jalr)                           state_n = S_EXEC_JUMP;
                else if (is_fence || is_system)                       state_n = S_SYSTEM;
                else                                                     state_n = S_FETCH; // illegal: nao trava
            end
            S_EXEC_ALU:    state_n = S_WB_ALU;
            S_EXEC_BRANCH: state_n = S_FETCH;
            S_EXEC_JUMP:   state_n = S_WB_ALU;
            S_MEM_ADDR:    state_n = is_store ? S_MEM_WRITE : S_MEM_READ;
            S_MEM_READ:    state_n = S_MEM_WAIT;
            S_MEM_WAIT:    state_n = S_WB_MEM;
            S_MEM_WRITE:   state_n = S_FETCH;
            S_EXEC_MUL:    state_n = S_WB_MUL;
            S_EXEC_CRC:    state_n = S_WB_CRC;
            S_SYSTEM:      state_n = S_FETCH;
            S_WB_ALU:      state_n = S_FETCH;
            S_WB_MEM:      state_n = S_FETCH;
            S_WB_MUL:      state_n = S_FETCH;
            S_WB_CRC:      state_n = S_FETCH;
            default:       state_n = S_FETCH;
        endcase
    end

    // ---- PC: write-enable centralizado (evita update duplicado, risco R-07) -
    // JAL/JALR passam por EXEC_JUMP (que ja grava o alvo) e DEPOIS por
    // WB_ALU (para escrever o link em rd) - WB_ALU NAO deve reescrever o PC
    // nesse caso, senao o PC avanca duas vezes (bug corrigido durante a
    // verificacao ISA; ver DECISIONS.md ADR sobre este ponto).
    always_comb begin
        pc_we_o = (state == S_EXEC_BRANCH) || (state == S_EXEC_JUMP) ||
                  (state == S_MEM_WRITE)   ||
                  ((state == S_WB_ALU) && !(is_jal || is_jalr)) ||
                  (state == S_WB_MEM)      || (state == S_WB_MUL)    ||
                  (state == S_WB_CRC)      || (state == S_SYSTEM);

        pc_sel_target_o = ((state == S_EXEC_BRANCH) && branch_taken_i) ||
                           (state == S_EXEC_JUMP);
    end

    // ---- IR: captura em FETCH -------------------------------------------
    assign ir_we_o = (state == S_FETCH);

    // ---- Selects de operando da ALU (funcao do opcode, ver banner acima) --
    always_comb begin
        alu_a_sel_pc_o  = is_auipc || is_jal || (state == S_EXEC_BRANCH);
        alu_b_sel_imm_o = !is_alu_reg; // ALU_REG usa rs2; todo o resto usa imediato
    end

    // ---- Tipo de imediato ----------------------------------------------------
    always_comb begin
        if (is_alu_imm || is_load || is_jalr)      imm_type_o = `IMM_I;
        else if (is_store)                          imm_type_o = `IMM_S;
        else if (is_branch)                         imm_type_o = `IMM_B;
        else if (is_lui || is_auipc)                imm_type_o = `IMM_U;
        else if (is_jal)                            imm_type_o = `IMM_J;
        else                                          imm_type_o = `IMM_I;
    end

    // ---- Selecao de operacao da ALU -----------------------------------------
    always_comb begin
        if (is_lui) begin
            alu_sel_o = `ALU_PASSB;
        end else if (is_alu_reg) begin
            case (funct3)
                `F3_ADD_SUB: alu_sel_o = (funct7 == `F7_ALU_ALT) ? `ALU_SUB : `ALU_ADD;
                `F3_SLL:     alu_sel_o = `ALU_SLL;
                `F3_SLT:     alu_sel_o = `ALU_SLT;
                `F3_SLTU:    alu_sel_o = `ALU_SLTU;
                `F3_XOR:     alu_sel_o = `ALU_XOR;
                `F3_SRL_SRA: alu_sel_o = (funct7 == `F7_ALU_ALT) ? `ALU_SRA : `ALU_SRL;
                `F3_OR:      alu_sel_o = `ALU_OR;
                `F3_AND:     alu_sel_o = `ALU_AND;
                default:     alu_sel_o = `ALU_ADD;
            endcase
        end else if (is_alu_imm) begin
            case (funct3)
                `F3_ADD_SUB: alu_sel_o = `ALU_ADD;   // ADDI
                `F3_SLT:     alu_sel_o = `ALU_SLT;   // SLTI
                `F3_SLTU:    alu_sel_o = `ALU_SLTU;  // SLTIU
                `F3_XOR:     alu_sel_o = `ALU_XOR;   // XORI
                `F3_OR:      alu_sel_o = `ALU_OR;    // ORI
                `F3_AND:     alu_sel_o = `ALU_AND;   // ANDI
                `F3_SLL:     alu_sel_o = `ALU_SLL;   // SLLI
                `F3_SRL_SRA: alu_sel_o = instr_i[30] ? `ALU_SRA : `ALU_SRL; // SRAI/SRLI
                default:     alu_sel_o = `ALU_ADD;
            endcase
        end else begin
            // AUIPC, LOAD, STORE (endereco), BRANCH (alvo), JAL/JALR (alvo)
            alu_sel_o = `ALU_ADD;
        end
    end

    // ---- Regfile / writeback --------------------------------------------------
    always_comb begin
        reg_we_o     = (state == S_WB_ALU) || (state == S_WB_MEM) ||
                        (state == S_WB_MUL) || (state == S_WB_CRC);
        rd_sel_pc4_o = (state == S_WB_ALU) && (is_jal || is_jalr);

        if (state == S_WB_MEM)      rd_sel_o = 2'b01;
        else if (state == S_WB_MUL) rd_sel_o = 2'b10;
        else if (state == S_WB_CRC) rd_sel_o = 2'b11;
        else                          rd_sel_o = 2'b00; // WB_ALU (ALUOut ou link)
    end

    // ---- Memoria de dados / endereco ---------------------------------------
    always_comb begin
        mem_oe_o           = (state == S_FETCH) || (state == S_MEM_READ);
        mem_we_o            = (state == S_MEM_WRITE);
        mem_addr_sel_alu_o = (state != S_FETCH);
    end

endmodule
