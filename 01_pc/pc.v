// Program Counter — 32-bit register, synchronous reset
module pc (
    input  wire        clk,      // clock
    input  wire        rst,      // synchronous reset (active high)
    input  wire [31:0] pc_next,  // next PC value (PC+4 or branch target)
    output reg  [31:0] pc        // current PC value → IMEM address
);
    always @(posedge clk) begin
        if (rst) pc <= 32'h0000_0000;
        else     pc <= pc_next;
    end
endmodule