// Partial RISC-V datapath: handles R-type and I-type ALU instructions
// Does NOT yet handle loads, stores, branches, or jumps
module core_ri (
    input wire clk,
    input wire rst
);
    // --- PC ---
    wire [31:0] pc, next_pc, instr;
    assign next_pc = pc + 32'd4;   // always advance (no branches yet)
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
    wire       reg_write, alu_src;
    wire [3:0] alu_op;
    wire [2:0] imm_sel;
    control ctrl(.opcode(opcode),.funct3(funct3),.funct7(funct7),
        .reg_write(reg_write),.alu_src(alu_src),
        .alu_op(alu_op),.imm_sel(imm_sel));

    // --- Register file ---
    wire [31:0] rdata1, rdata2, wb_data;
    reg_file rf(.clk(clk),.we(reg_write),.waddr(rd),.wdata(wb_data),
               .raddr1(rs1),.rdata1(rdata1),.raddr2(rs2),.rdata2(rdata2));

    // --- ImmGen ---
    wire [31:0] imm;
    immgen ig(.instr(instr),.imm_sel(imm_sel),.imm(imm));

    // --- ALUSrc mux ---
    wire [31:0] alu_b = alu_src ? imm : rdata2;

    // --- ALU ---
    wire [31:0] alu_result;
    wire        zero;
    alu alu0(.a(rdata1),.b(alu_b),.alu_op(alu_op),.result(alu_result),.zero(zero));

    // --- Write-back (ALU result only for R/I) ---
    assign wb_data = alu_result;
endmodule