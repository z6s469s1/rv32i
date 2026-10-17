//set the time unit and time precision
`timescale 1ns / 1ps

module tb_pc;

    reg clk;
    reg rst;
    reg [31:0] next_pc;
    wire [31:0] pc;

    //instantiate the pc module
    pc dut(
        .clk(clk),
        .rst(rst),
        .next_pc(next_pc),
        .pc(pc)
    );

    //define the check task
    task check_pc(
        input [31:0] pc,
        input [31:0] expected_pc
    );
        if(pc !== expected_pc) begin
            $display("Test failed: pc = %h, expected = %h", pc, expected_pc);
            $finish;
        end else begin
            $display("Test passed: pc = %h", pc);
        end
    endtask

    //clock generation
    always #5 clk = ~clk;

    //testbench
    initial begin
        //save waveform
        $dumpfile("tb_pc.vcd");
        $dumpvars(0, tb_pc);
        
        //test case 1: reset
        clk = 0;
        rst = 1;
        next_pc = 32'h0011_0000;
        @(posedge clk);
        #1;
        check_pc(pc, 32'h0000_0000);

        //test case 2: check pc whether it is updated correctly
        for (integer i = 0; i < 32'hFFFF_FFFF; i+=32'h0001_0001) begin
            rst = 0;
            next_pc = i;
            @(posedge clk);
            #1;
            check_pc(pc, i);
        end
        
        $finish;
    end
endmodule