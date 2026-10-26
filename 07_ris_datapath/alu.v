module alu
(
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_op,
    output reg [31:0] result,
    output reg zero
);

    wire [4:0] shamt = b[4:0];   // shift amount is lower 5 bits of B

    always @(*) begin
        case (alu_op)
            4'b0000: result = a + b;                          // ADD
            4'b0001: result = a - b;                          // SUB
            4'b0010: result = a & b;                          // AND
            4'b0011: result = a | b;                          // OR
            4'b0100: result = a ^ b;                          // XOR
            4'b0101: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
            4'b0110: result = (a < b)                 ? 32'd1 : 32'd0; // SLTU
            4'b0111: result = a << shamt;                     // SLL
            4'b1000: result = a >> shamt;                     // SRL
            4'b1001: result = $signed(a) >>> shamt;           // SRA
            default: result = 32'd0;
        endcase

        zero = (result == 32'h0000_0000) ? 1'b1 : 1'b0;
    end

endmodule