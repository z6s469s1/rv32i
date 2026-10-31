// dmem.v — Data Memory (byte-addressable, 1 KB)
// Synchronous write, asynchronous read, byte/half/word via funct3
module dmem #(parameter DEPTH = 256) (
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] wdata,
    input  [ 2:0] funct3,
    output reg [31:0] rdata
);
    // Storage: word-addressed internally, byte-addressed externally
    reg [7:0] mem [0:(DEPTH*4)-1];

    // --- Synchronous Write ---
    always @(posedge clk) begin
        if (we) begin
            case (funct3)
                3'b000: begin // SB — store byte
                    mem[addr]   <= wdata[7:0];
                end
                3'b001: begin // SH — store half-word
                    mem[addr]   <= wdata[7:0];
                    mem[addr+1] <= wdata[15:8];
                end
                3'b010: begin // SW — store word
                    mem[addr]   <= wdata[7:0];
                    mem[addr+1] <= wdata[15:8];
                    mem[addr+2] <= wdata[23:16];
                    mem[addr+3] <= wdata[31:24];
                end
                default: ; // ignore illegal funct3
            endcase
        end
    end

    // --- Asynchronous Read ---
    always @(*) begin
        case (funct3)
            3'b000: // LB — sign-extend byte
                rdata = {{24{mem[addr][7]}}, mem[addr]};
            3'b001: // LH — sign-extend half-word
                rdata = {{16{mem[addr+1][7]}},
                          mem[addr+1], mem[addr]};
            3'b010: // LW — full word
                rdata = {mem[addr+3], mem[addr+2],
                          mem[addr+1], mem[addr]};
            3'b100: // LBU — zero-extend byte
                rdata = {24'b0, mem[addr]};
            3'b101: // LHU — zero-extend half-word
                rdata = {16'b0, mem[addr+1], mem[addr]};
            default: rdata = 32'b0;
        endcase
    end
endmodule