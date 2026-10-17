//set the time unit and time precision
`timescale 1ns / 1ps

module tb_alu;

    reg [31:0] a;
    reg [31:0] b;
    reg [3:0] alu_op;
    wire [31:0] result;
    wire zero;

    //instantiate the alu module
    alu dut(
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

  
    //define the check task
    integer error_count = 0;
    task check_reg(
        input [31:0] expected_result,
        input expected_zero
    );
        if(result !== expected_result || zero !== expected_zero) begin
            $display("Test failed: result = %h, expected = %h zero = %b, expected = %b", result, expected_result, zero, expected_zero);
            error_count = error_count + 1;
        end else begin
            $display("Test passed: result = %h", result);
        end
    endtask

    //testbench
    initial begin
        //save waveform
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);
        
        //test case 1: add
        a = 32'h0000_0001;
        b = 32'h0000_0002;
        alu_op = 4'b0000; //add 
        #1;
        check_reg(32'h0000_0003, 1'b0);

        //test case 2: sub
        a = 32'h0000_0003;
        b = 32'h0000_0002;
        alu_op = 4'b0001; //sub
        #1;
        check_reg(32'h0000_0001, 1'b0);

        //test case 3: and
        a = 32'h0000_0003;
        b = 32'h0000_0002;
        alu_op = 4'b0010; //and
        #1;
        check_reg(32'h0000_0002, 1'b0);

        //test case 4: or
        a = 32'h0000_0003;
        b = 32'h0000_0002;
        alu_op = 4'b0011; //or
        #1;
        check_reg(32'h0000_0003, 1'b0);

        //test case 5: xor
        a = 32'h0000_0003;
        b = 32'h0000_0002;
        alu_op = 4'b0100; //xor
        #1;
        check_reg(32'h0000_0001, 1'b0);

        //test case 6: slt
        a = 32'h0000_0001;
        b = 32'h0000_0002;
        alu_op = 4'b0101; //slt
        #1;
        check_reg(32'h0000_0001, 1'b0);

        //test case 7: sltu
        a = 32'h0000_0001;
        b = 32'h0000_0002;
        alu_op = 4'b0110; //sltu
        #1;
        check_reg(32'h0000_0001, 1'b0);

        //test case 8: sll
        a = 32'h0000_0001;
        b = 32'h0000_0002;  
        alu_op = 4'b0111; //sll
        #1;
        check_reg(32'h0000_0004, 1'b0);

        //test case 9: srl
        a = 32'h0000_0004;
        b = 32'h0000_0002;
        alu_op = 4'b1000; //srl
        #1;
        check_reg(32'h0000_0001, 1'b0);

        //test case 10: sra
        a = 32'hFFFF_FFFC;
        b = 32'h0000_0002;
        alu_op = 4'b1001; //sra
        #1;
        check_reg(32'hFFFF_FFFF, 1'b0);

        //test case 11: zero flag
        a = 32'h0000_0001;
        b = 32'h0000_0001;
        alu_op = 4'b0001; //sub
        #1;
        check_reg(32'h0000_0000, 1'b1);

        if (error_count == 0) begin
            $display("All tests passed!");
        end else begin
            $display("%d tests failed.", error_count);
        end
        $finish;
    end
endmodule