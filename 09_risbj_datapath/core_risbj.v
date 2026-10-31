// Partial RISC-V datapath: handles R-type and I-type ALU instructions
// Does NOT yet handle loads, stores, branches, or jumps
module core_risb (
    input wire clk,
    input wire rst
);
    // --- PC ---
    wire [31:0] pc, instr;
    reg [31:0] next_pc;
   
    always @(*) begin
        if (branch_taken & is_branch) begin
            next_pc = branch_target;
        end else if (is_jal) begin
            next_pc = pc + imm;
        end else if (is_jalr) begin
            next_pc = (rdata1 + imm) & 32'hfffffffe;
        end else begin
            next_pc = pc + 32'd4;
        end 
    end

    pc    pc_reg (.clk(clk),.rst(rst),.next_pc(next_pc),.pc(pc));
    imem  imem0  (.addr(pc),.instr(instr));

    // --- Decode ---
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // --- Control ---
    wire       reg_write, alu_src, is_branch;
    wire [3:0] alu_op;
    wire [2:0] imm_sel;
    wire       mem_write, wb_sel;
    wire       is_jal, is_jalr;
    control ctrl(.opcode(opcode),.funct3(funct3),.funct7(funct7),
        .reg_write(reg_write),.alu_src(alu_src),.is_branch(is_branch),
        .alu_op(alu_op),.imm_sel(imm_sel),.mem_write(mem_write),.wb_sel(wb_sel),
        .is_jal(is_jal),.is_jalr(is_jalr));

    // --- Register file ---
    wire [31:0] rdata1, rdata2;
    reg [31:0] wb_data;
    reg_file rf(.clk(clk),.we(reg_write),.waddr(rd),.wdata(wb_data),
               .raddr1(rs1),.rdata1(rdata1),.raddr2(rs2),.rdata2(rdata2));

    // --- ImmGen ---
    wire [31:0] imm;
    immgen ig(.instr(instr),.imm_sel(imm_sel),.imm(imm));

    // --- ALUSrc mux ---
    wire [31:0] alu_b = alu_src ? imm : rdata2;

    // --- ALU ---
    wire [31:0] alu_result;
    wire        zero, alu_lt, alu_ltu;
    alu alu0(.a(rdata1),.b(alu_b),.alu_op(alu_op),.result(alu_result),.zero(zero),.alu_lt(alu_lt),.alu_ltu(alu_ltu));

    // --- Branch Unit ---
    wire branch_taken;
    wire [31:0] branch_target;
    branch_unit bu(.funct3(funct3),.zero(zero),.alu_lt(alu_lt),.alu_ltu(alu_ltu),.pc(pc),.b_imm(imm),.branch_taken(branch_taken),.branch_target(branch_target));


    // --- Data memory ---
    wire [31:0] mem_rdata;
    dmem dmem0(.clk(clk), .we(mem_write),.addr(alu_result), .wdata(rdata2),.funct3(funct3), .rdata(mem_rdata));
    // --- Write-back (ALU result only for R/I) ---
    always@(*) begin
        if (is_jal || is_jalr) begin
            wb_data = pc + 32'd4; // Return address for JAL/JALR
        end else begin
            if (wb_sel) begin
                wb_data = mem_rdata; // Load data from memory
            end else begin
                wb_data = alu_result; // ALU result for R/I types
            end
        end
    end
endmodule