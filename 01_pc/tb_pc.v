`timescale 1ns/1ps
module tb_pc;
    reg        clk, rst;
    reg [31:0] pc_next;
    wire[31:0] pc;

    pc dut (.clk(clk), .rst(rst), .pc_next(pc_next), .pc(pc));

    // Record all testbench and DUT signals for waveform viewing.
    initial begin
        $dumpfile("pc.vcd");
        $dumpvars(0, tb_pc);
    end

    // 10 ns clock
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors = 0;
    task check(input [31:0] exp);
        if (pc !== exp) begin
            $display("FAIL: pc=%0h expected=%0h", pc, exp);
            errors = errors + 1;
        end else
            $display("ok:   pc=%0h", pc);
    endtask

    initial begin
        // --- reset ---
        rst=1; pc_next=32'h0; @(posedge clk); #1;
        check(32'h0000_0000);    // after reset, PC=0

        // --- advance PC+4 each cycle ---
        rst=0;
        pc_next=32'h0000_0004; @(posedge clk); #1; check(32'h0000_0004);
        pc_next=32'h0000_0008; @(posedge clk); #1; check(32'h0000_0008);
        pc_next=32'h0000_000C; @(posedge clk); #1; check(32'h0000_000C);

        // --- branch jump to address ---
        pc_next=32'h0000_0100; @(posedge clk); #1; check(32'h0000_0100);

        // --- reset again ---
        rst=1; pc_next=32'h0; @(posedge clk); #1; check(32'h0000_0000);

        if (errors==0) $display("ALL TESTS PASSED");
        else           $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule