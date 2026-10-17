//set the time unit and time precision
`timescale 1ns / 1ps

module tb_reg_file;

    reg clk;
    reg we;
    reg [4:0] waddr;
    reg [31:0] wdata;
    reg [4:0] raddr1;
    reg [4:0] raddr2;
    wire [31:0] rdata1;
    wire [31:0] rdata2;

    //instantiate the reg_file module
    reg_file dut(
        .clk(clk),
        .we(we),
        .waddr(waddr),
        .wdata(wdata),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    //define the check task
    integer error_count = 0;
    task check_reg(
        input [31:0] reg_value,
        input [31:0] expected_value
    );
        if(reg_value !== expected_value) begin
            $display("Test failed: reg = %h, expected = %h", reg_value, expected_value);
            error_count = error_count + 1;
        end else begin
            $display("Test passed: reg = %h", reg_value);
        end
    endtask

    //clock generation
    always #5 clk = ~clk;

    //testbench
    initial begin
        //save waveform
        $dumpfile("tb_reg_file.vcd");
        $dumpvars(0, tb_reg_file);
        
        clk = 0;
        //test case 1: write to register 1 and 10, then read them back
        we = 1;
        waddr = 5'h1;
        wdata = 32'h0000_0001;
        @(posedge clk);
        #1;
        we = 1;
        waddr = 5'h1F;
        wdata = 32'h0000_0020;
        @(posedge clk);
        #1;
        we = 0;
        raddr1 = 5'h1;
        raddr2 = 5'h1F;
        #1;
        check_reg(rdata1, 32'h0000_0001);
        check_reg(rdata2, 32'h0000_0020);

        //test case 2: write to register 0, then read it back
        we = 1;
        waddr = 5'h0;
        wdata = 32'hFFFF_FFFF; 
        @(posedge clk);
        #1;
        we = 0;
        raddr1 = 5'h0;
        #1;
        check_reg(rdata1, 32'h0000_0000);

        if (error_count == 0) begin
            $display("All tests passed!");
        end else begin
            $display("%d tests failed.", error_count);
        end
        $finish;
    end
endmodule