// =============================================================================
// rv32_core.sv - Integracao do datapath multicycle RV32I_Zmmul_Xicrc.
// Registradores de estagio: pc_reg, ir_reg, alu_out_reg, mult_out_reg,
// crc_out_reg (ALUOut/MultOut/CrcOut sao "free-running", sem enable
// dedicado - ver banner de control_unit.sv). Nenhuma logica de decisao mora
// aqui: apenas fiacao + registradores (regra da secao 5 do Plano Mestre).
//
// Interface de memoria externa conforme secao 3.2 do Plano Mestre.
// =============================================================================
`include "rv32_defs.vh"

module rv32_core (
    input  logic         clk_i,
    input  logic          rst_i,

    output logic [31:0]  mem_addr_o,
    output logic [31:0]  mem_wdata_o,
    input  logic [31:0]  mem_rdata_i,
    output logic          mem_oe_o,
    output logic          mem_we_o,
    output logic [3:0]   mem_bw_o,

    // Diagnostico / evidencia (nao faz parte do contrato fisico obrigatorio)
    output logic [31:0]  pc_dbg_o,
    output logic [3:0]   state_dbg_o,
    output logic          halt_o,
    output logic          illegal_o
);

    // ---- Registradores de estagio ------------------------------------------
    logic [31:0] pc_reg, ir_reg;
    logic [31:0] alu_out_reg, mult_out_reg, crc_out_reg, link_reg;

    // ---- Fios de controle (control_unit) -----------------------------------
    logic [3:0] state;
    logic       pc_we, pc_sel_target, ir_we;
    logic [3:0] alu_sel;
    logic       alu_a_sel_pc, alu_b_sel_imm;
    logic [2:0] imm_type;
    logic       reg_we;
    logic [1:0] rd_sel;
    logic       rd_sel_pc4;
    logic       mem_oe, mem_we, mem_addr_sel_alu, is_store;

    // ---- Campos do IR --------------------------------------------------------
    wire [4:0] rs1_addr = ir_reg[19:15];
    wire [4:0] rs2_addr = ir_reg[24:20];
    wire [4:0] rd_addr  = ir_reg[11:7];
    wire [2:0] funct3   = ir_reg[14:12];
    wire       is_jalr_w = (ir_reg[6:0] == `OPC_JALR);

    // ---- Fios do datapath ------------------------------------------------------
    logic [31:0] rs1_rdata, rs2_rdata;
    logic [31:0] imm;
    logic [31:0] alu_a, alu_b, alu_result;
    logic         alu_zero;
    logic         branch_taken;
    logic [31:0] mult_result;
    logic [31:0] crc_result;
    logic         crc_blocked;
    logic [31:0] lsu_wdata;
    logic [3:0]  lsu_bw;
    logic [31:0] lsu_load_data;
    logic         lsu_misaligned;
    logic [31:0] pc_plus4, pc_target, rd_wdata;

    // ---- control_unit ------------------------------------------------------
    control_unit u_ctrl (
        .clk_i             (clk_i),
        .rst_i             (rst_i),
        .instr_i           (ir_reg),
        .branch_taken_i    (branch_taken),
        .state_o           (state),
        .pc_we_o           (pc_we),
        .pc_sel_target_o   (pc_sel_target),
        .ir_we_o           (ir_we),
        .alu_sel_o         (alu_sel),
        .alu_a_sel_pc_o    (alu_a_sel_pc),
        .alu_b_sel_imm_o   (alu_b_sel_imm),
        .imm_type_o        (imm_type),
        .reg_we_o          (reg_we),
        .rd_sel_o          (rd_sel),
        .rd_sel_pc4_o      (rd_sel_pc4),
        .mem_oe_o          (mem_oe),
        .mem_we_o          (mem_we),
        .mem_addr_sel_alu_o(mem_addr_sel_alu),
        .is_store_o        (is_store),
        .halt_o            (halt_o),
        .illegal_o         (illegal_o)
    );

    // ---- Regfile --------------------------------------------------------------
    regfile u_regfile (
        .clk_i      (clk_i),
        .rst_i      (rst_i),
        .rs1_addr_i (rs1_addr),
        .rs2_addr_i (rs2_addr),
        .rd_addr_i  (rd_addr),
        .rd_wdata_i (rd_wdata),
        .rd_we_i    (reg_we),
        .rs1_rdata_o(rs1_rdata),
        .rs2_rdata_o(rs2_rdata)
    );

    // ---- Gerador de imediato --------------------------------------------------
    imm_gen u_imm_gen (
        .instr_i    (ir_reg),
        .imm_type_i (imm_type),
        .imm_o      (imm)
    );

    // ---- ALU compartilhada ------------------------------------------------------
    assign alu_a = alu_a_sel_pc  ? pc_reg    : rs1_rdata;
    assign alu_b = alu_b_sel_imm ? imm       : rs2_rdata;

    alu u_alu (
        .a_i       (alu_a),
        .b_i       (alu_b),
        .alu_sel_i (alu_sel),
        .result_o  (alu_result),
        .zero_o    (alu_zero)
    );

    // ---- Comparador de branch --------------------------------------------------
    branch_cmp u_branch_cmp (
        .rs1_i    (rs1_rdata),
        .rs2_i    (rs2_rdata),
        .funct3_i (funct3),
        .taken_o  (branch_taken)
    );

    // ---- Multiplicador Zmmul ---------------------------------------------------
    mult_unit u_mult (
        .a_i       (rs1_rdata),
        .b_i       (rs2_rdata),
        .funct3_i  (funct3),
        .result_o  (mult_result)
    );

    // ---- CRC Xicrc (BLOCKED-XICRC, ver crc_unit.sv) -----------------------------
    crc_unit u_crc (
        .rs1_i         (rs1_rdata),
        .rs2_i         (rs2_rdata),
        .funct3_i      (funct3),
        .result_o      (crc_result),
        .crc_blocked_o (crc_blocked)
    );

    // ---- LSU --------------------------------------------------------------------
    lsu u_lsu (
        .addr_lsb_i    (alu_out_reg[1:0]),
        .funct3_i      (funct3),
        .is_store_i    (is_store),
        .store_data_i  (rs2_rdata),
        .mem_rdata_i   (mem_rdata_i),
        .mem_wdata_o   (lsu_wdata),
        .bw_o          (lsu_bw),
        .load_data_o   (lsu_load_data),
        .misaligned_o  (lsu_misaligned)
    );

    // ---- PC: write centralizado no control_unit (risco R-07) --------------------
    assign pc_plus4  = pc_reg + 32'd4;
    assign pc_target = is_jalr_w ? {alu_result[31:1], 1'b0} : alu_result; // JALR: target[0]=0

    always_ff @(posedge clk_i) begin
        if (rst_i) pc_reg <= `PC_RESET;
        else if (pc_we) pc_reg <= pc_sel_target ? pc_target : pc_plus4;
    end

    // ---- IR: captura em FETCH ---------------------------------------------------
    always_ff @(posedge clk_i) begin
        if (rst_i) ir_reg <= 32'h0000_0013; // NOP
        else if (ir_we) ir_reg <= mem_rdata_i;
    end

    // ---- Registradores de resultado (free-running, estilo ALUOut classico) ------
    // link_reg: captura pc_plus4 NO MESMO ciclo/borda em que pc_reg pode estar
    // sendo atualizado para o alvo do salto (EXEC_JUMP). Ambos usam o mesmo
    // valor pre-borda de pc_reg (semantica nao-blocante), entao link_reg fica
    // com PC_do_JAL+4 mesmo depois que pc_reg ja aponta para o destino - sem
    // isso, WB_ALU leria pc_plus4 do PC JA saltado (bug encontrado e corrigido
    // durante a verificacao ISA de JAL/JALR; ver DECISIONS.md).
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            alu_out_reg  <= 32'd0;
            mult_out_reg <= 32'd0;
            crc_out_reg  <= 32'd0;
            link_reg     <= 32'd0;
        end else begin
            alu_out_reg  <= alu_result;
            mult_out_reg <= mult_result;
            crc_out_reg  <= crc_result;
            link_reg     <= pc_plus4;
        end
    end

    // ---- Mux de escrita no regfile -----------------------------------------------
    always_comb begin
        if (rd_sel_pc4) rd_wdata = link_reg;
        else case (rd_sel)
            2'b00:   rd_wdata = alu_out_reg;
            2'b01:   rd_wdata = lsu_load_data;
            2'b10:   rd_wdata = mult_out_reg;
            2'b11:   rd_wdata = crc_out_reg;
            default: rd_wdata = alu_out_reg;
        endcase
    end

    // ---- Barramento de memoria externo --------------------------------------------
    assign mem_addr_o  = mem_addr_sel_alu ? alu_out_reg : pc_reg;
    assign mem_wdata_o = lsu_wdata;
    assign mem_oe_o    = mem_oe;
    assign mem_we_o    = mem_we;
    assign mem_bw_o    = lsu_bw;

    // ---- Diagnostico --------------------------------------------------------------
    assign pc_dbg_o    = pc_reg;
    assign state_dbg_o = state;

    // ---- Assertions de invariantes (secao 6.1) - somente simulacao ---------------
`ifndef SYNTHESIS
    // x0 permanece zero
    // (garantido estruturalmente em regfile.sv; checagem redundante aqui)
    always_ff @(posedge clk_i) begin
        if (!rst_i) begin
            assert (u_regfile.rs1_addr_i != 5'd0 || rs1_rdata == 32'd0)
                else $error("[INVARIANT] x0 != 0 em rs1_rdata");
            assert (!(mem_we_o && mem_oe_o))
                else $error("[INVARIANT] mem_we_o e mem_oe_o simultaneos");
            assert (!(lsu_bw != 4'b0000) || is_store)
                else $error("[INVARIANT] bw != 0 fora de store");
        end
    end
`endif

endmodule
