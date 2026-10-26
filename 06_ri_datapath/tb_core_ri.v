`timescale 1ns/1ps
module tb_core_ri;
    
    core_ri dut(.clk(clk),.rst(rst));
    
    // access regfile for checking
    wire [31:0] x1=dut.rf.registers[1],x2=dut.rf.registers[2],x3=dut.rf.registers[3];
    wire [31:0] x4=dut.rf.registers[4],x5=dut.rf.registers[5],x6=dut.rf.registers[6];
    
    integer errors=0;
    task chk(input [31:0]got,input [31:0]exp,input [63:0]name);
        if(got!==exp)begin $display("FAIL %s: got=%0h exp=%0h",name,got,exp);errors=errors+1;end
        else $display("ok   %s = %0h",name,got);
    endtask
    
    reg clk=0,rst=0;
    always #5 clk=~clk;
    initial begin
        $dumpfile("tb_core_ri.vcd");
        $dumpvars(0, tb_core_ri);

        // reset
        @(posedge clk); rst=1; 
        @(posedge clk); rst=0; 
        
        // run 8 cycles
        repeat(8) @(posedge clk); 
        #1; 
        
        // check results
        chk(x1,32'd5,"x1 (addi x1 5)");
        chk(x2,32'd10,"x2 (addi x2 10)");
        chk(x3,32'd15,"x3 (add x3, x1, x2)");
        chk(x4,32'hFFFFFFFB,"x4 (sub x4, x1, x2)");
        chk(x5,32'd0,"x5 (and x5, x1, x2)");
        chk(x6,32'd15,"x6 (or x6, x1, x2)");

        if(errors==0) 
            $display("ALL TESTS PASSED"); 
        else 
            $display("%0d FAILED",errors);
        $finish;
    end
endmodule