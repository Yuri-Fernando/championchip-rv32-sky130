// =============================================================================
// regfile.sv - Banco de 32 registradores x32 bits (RV32I).
// Leitura combinacional (assincrona) em rs1/rs2, escrita sincrona em rd.
// x0 e hardwired a zero (leitura sempre 0; escritas em rd=0 sao ignoradas).
// =============================================================================
module regfile (
    input  logic        clk_i,
    input  logic         rst_i,
    input  logic [4:0]   rs1_addr_i,
    input  logic [4:0]   rs2_addr_i,
    input  logic [4:0]   rd_addr_i,
    input  logic [31:0]  rd_wdata_i,
    input  logic         rd_we_i,
    output logic [31:0]  rs1_rdata_o,
    output logic [31:0]  rs2_rdata_o
);

    logic [31:0] regs [1:31]; // x1..x31 (x0 nao e armazenado)
    integer i;

    // Leitura combinacional, x0 fixo em zero
    assign rs1_rdata_o = (rs1_addr_i == 5'd0) ? 32'd0 : regs[rs1_addr_i];
    assign rs2_rdata_o = (rs2_addr_i == 5'd0) ? 32'd0 : regs[rs2_addr_i];

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            for (i = 1; i <= 31; i = i + 1) regs[i] <= 32'd0;
        end else if (rd_we_i && (rd_addr_i != 5'd0)) begin
            regs[rd_addr_i] <= rd_wdata_i;
        end
    end

endmodule
