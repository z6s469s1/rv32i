// Instruction Memory — combinational ROM, word-addressed
// Holds up to 256 instructions (1 KB). Pre-load with $readmemh.
// 32 bit = 4 bytes, so 256 instructions = 1024 bytes = 1 KB
module imem #(parameter DEPTH = 256) (
    input  wire [31:0] addr,   // byte address from PC
    output wire [31:0] instr   // 32-bit instruction word
);
    reg [31:0] mem [0:DEPTH-1];

    // Load program at simulation start.
    // Replace "program.hex" with your assembled .hex file.
    initial $readmemh("program.hex", mem);

    // Word-aligned read: divide byte address by 4
    assign instr = mem[addr[31:2]];
endmodule