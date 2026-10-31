module reg_file
(
    input wire clk,
    input wire we,                  //write enable
    input wire [4:0] waddr,         //rd
    input wire [31:0] wdata,
    input wire [4:0] raddr1,        //rs1
    input wire [4:0] raddr2,        //rs2
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);

    reg [31:0] registers [0:31];

    initial begin
        for (integer i = 0; i < 32; i = i + 1) begin
            registers[i] <= 32'h0000_0000;
        end
    end

    always @(posedge clk)begin
        if(we && waddr != 5'h0) begin
                registers[waddr] <= wdata;
        end
    end

    
    assign rdata1 = raddr1 == 5'h0 ? 32'h0000_0000 : registers[raddr1];
    assign rdata2 = raddr2 == 5'h0 ? 32'h0000_0000 : registers[raddr2];

endmodule