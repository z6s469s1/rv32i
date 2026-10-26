// RISC-V Control Unit — decodes opcode, drives datapath
module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        alu_src,
    output reg  [3:0] alu_op,
    output reg  [2:0] imm_sel,
    output reg       mem_write,
    output reg       wb_sel
);
    localparam R   = 7'b0110011;  // R-type
    localparam I   = 7'b0010011;  // I-type ALU
    localparam S   = 7'b0100011;  // S-type store
    localparam L   = 7'b0000011;  // I-type load

    always @(*) begin
        // defaults — safe values
        {reg_write,alu_src,mem_write,wb_sel}=4'b0;
        alu_op=4'b0000; imm_sel=3'b000;
        case (opcode)
            R:  
                begin 
                    alu_src=0;
                    reg_write=1;
                    mem_write=0;
                    wb_sel=3'b000;
                    case({funct7[5],funct3})
                        4'b0000: alu_op=4'b0000; // ADD
                        4'b1000: alu_op=4'b0001; // SUB
                        4'b0111: alu_op=4'b0010; // AND
                        4'b0110: alu_op=4'b0011; // OR
                        4'b0100: alu_op=4'b0100; // XOR
                        4'b0010: alu_op=4'b0101; // SLT
                        4'b0011: alu_op=4'b0110; // SLTU
                        4'b0001: alu_op=4'b0111; // SLL
                        4'b0101: alu_op=4'b1000; // SRL
                        4'b1101: alu_op=4'b1001; // SRA
                        default: alu_op=4'b0000;
                    endcase
                end
            I:   begin 
                    alu_src=1; 
                    reg_write=1; 
                    imm_sel=3'b000;
                    mem_write=0;
                    wb_sel=3'b000;
                    case(funct3)
                        3'h0: alu_op=4'b0000; // ADDI
                        3'h7: alu_op=4'b0010; // ANDI
                        3'h6: alu_op=4'b0011; // ORI
                        3'h4: alu_op=4'b0100; // XORI
                        3'h2: alu_op=4'b0101; // SLTI
                        3'h3: alu_op=4'b0110; // SLTIU
                        3'h1: alu_op=4'b0111; // SLLI
                        3'h5: alu_op=(funct7[5])?4'b1001:4'b1000; // SRAI/SRLI
                        default: alu_op=4'b0000;
                    endcase 
                end
            S:   begin 
                    alu_src=1; 
                    reg_write=0; 
                    imm_sel=3'b001;
                    mem_write=1;
                    wb_sel=3'b000;
                    alu_op=4'b0000; 
                end
            L:   begin 
                    alu_src=1; 
                    reg_write=1; 
                    imm_sel=3'b000;
                    mem_write=0;
                    wb_sel=3'b001;
                    alu_op=4'b0000; 
                end
            default: ;
        endcase
    end
endmodule