`timescale 1ns/1ps
module tb_core_risb;
    
    core_risb dut(.clk(clk),.rst(rst));
    
    // access regfile for checking
    wire [31:0] x1=dut.rf.registers[1],x2=dut.rf.registers[2],x3=dut.rf.registers[3];
    wire [31:0] x4=dut.rf.registers[4],x5=dut.rf.registers[5],x6=dut.rf.registers[6];
    
    integer errors=0;
    task chk(input [31:0]got,input [31:0]exp,input [127:0]name);
        if(got!==exp)begin $display("FAIL %-16s: got=%0h exp=%0h",$sformatf("%0s",name),got,exp);errors=errors+1;end
        else $display("ok   %-16s = %0h",$sformatf("%0s",name),got);
    endtask
    
    reg clk=0,rst=0;
    always #5 clk=~clk;
    initial begin
        $dumpfile("tb_core_risb.vcd");
        $dumpvars(0, tb_core_risb);

        // reset
        @(negedge clk); rst=1; 
        @(negedge clk); rst=0; 
        
        //R&I Type Instructions
        // run 8 cycles
        repeat(8) @(posedge clk); 
        #1; 
        // check results
        chk(x1,32'd5,"I ADDI x1");
        chk(x2,32'd10,"I ADDI x2");
        chk(x3,32'd15,"R ADD x3");
        chk(x4,32'hFFFFFFFB,"R SUB x4");
        chk(x5,32'd0,"R AND x5");
        chk(x6,32'd15,"R OR x6");    

        //S Type Instructions
        // run 3 cycles
        repeat(3) @(posedge clk); 
        #1; 
        // check S results
        chk(x1,32'd42,"I ADDI SW source");
        chk(x2,32'd42,"SW/LW x2");

        //B Type Instructions
        // run 5 cycles: nop + initialize x10, x11, x12, x13
        repeat(5) @(posedge clk);
        #1;
        chk(dut.pc,32'h40,"B start PC");

        // BEQ taken: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'h48,"BEQ taken");

        // BEQ not taken: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'h50,"BEQ not taken");

        // BNE taken: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'h58,"BNE taken");

        // BNE not taken: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'h60,"BNE not taken");

        // BLT taken: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'h68,"BLT taken");

        // BLT not taken: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'h70,"BLT not taken");

        // BGE taken: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'h78,"BGE taken");

        // BGE not taken: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'h80,"BGE not taken");

        // BLTU taken: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'h88,"BLTU taken");

        // BLTU not taken: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'h90,"BLTU not taken");

        // BGEU taken: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'h98,"BGEU taken");

        // BGEU not taken: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'ha0,"BGEU not taken");

        // BLT equal: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'ha8,"BLT equal");

        // BGE equal: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'hb0,"BGE equal");

        // BLTU equal: execute the fall-through nop
        repeat(2) @(posedge clk);
        #1;
        chk(dut.pc,32'hb8,"BLTU equal");

        // BGEU equal: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'hc0,"BGEU equal");

        // BLT signed min: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'hc8,"BLT signed min");

        // BGE signed max: skip the next instruction
        repeat(1) @(posedge clk);
        #1;
        chk(dut.pc,32'hd0,"BGE signed max");

        // run 8 cycles: initialize counter + loop 3 times + completion marker
        repeat(8) @(posedge clk);
        #1;
        // check B results
        chk(dut.pc,32'he0,"B final PC");
        chk(dut.rf.registers[14],32'd0,"loop counter");
        chk(dut.rf.registers[30],32'd1,"B completed");
        chk(dut.rf.registers[31],32'd0,"B skipped writes");

        if(errors==0) 
            $display("ALL TESTS PASSED"); 
        else 
            $display("%0d FAILED",errors);
        $finish;
    end
endmodule
