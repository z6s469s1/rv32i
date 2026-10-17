//set the time unit and time precision
`timescale 1ns / 1ps

module tb_imem;

    reg clk;
    reg rst;
    reg [31:0] next_pc;
    wire [31:0] pc;
    wire [31:0] instr;
    reg [31:0] expected_instr [0:3];
    integer i;

    //instantiate the pc module
    pc _pc(
        .clk(clk),
        .rst(rst),
        .next_pc(next_pc),
        .pc(pc)
    );

    imem _imem(
        .addr(pc),
        .instr(instr)
    );

    //define the check task
    integer error_count = 0;
    task check_instr(
        input [31:0] expected_pc,
        input [31:0] expected_instr
    );
        if(pc !== expected_pc || instr !== expected_instr) begin
            $display("Test failed: pc = %h, instr = %h, expected = %h", pc, instr, expected_instr);
            error_count = error_count + 1;
        end else begin
            $display("Test passed: pc = %h, instr = %h", pc, instr);
        end
    endtask

    //clock generation
    always #5 clk = ~clk;

    //testbench
    initial begin
        //save waveform
        $dumpfile("tb_imem.vcd");
        $dumpvars(0, tb_imem);


        expected_instr[0] = 32'h00500093;
        expected_instr[1] = 32'h00A00113;
        expected_instr[2] = 32'h002081B3;
        expected_instr[3] = 32'h00000013;

        clk = 0;
        rst = 0;
        for (i = 0; i < 4; i = i + 1) begin
            next_pc = i * 4;
            @(posedge clk);
            #1;
            check_instr(next_pc, expected_instr[i]);
        end

        if (error_count == 0) begin
            $display("All tests passed!");
        end else begin
            $display("%d tests failed.", error_count);
        end        
        $finish;
    end
endmodule
