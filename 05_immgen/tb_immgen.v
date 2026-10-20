`timescale 1ns / 1ps

module tb_immgen;
    reg [31:0] instr;
    reg [2:0] imm_sel;
    wire [31:0] imm;
    integer error_count = 0;
    integer test_count = 0;

    immgen dut (
        .instr(instr),
        .imm_sel(imm_sel),
        .imm(imm)
    );

    task check_imm;
        input [8*40-1:0] name;
        input [2:0] select;
        input [31:0] instruction;
        input [31:0] expected;
        begin
            instr = instruction;
            imm_sel = select;
            #1;
            test_count = test_count + 1;
            if (imm !== expected) begin
                $display("FAIL %0s: sel=%b instr=%h imm=%h expected=%h",
                         name, imm_sel, instr, imm, expected);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("immgen.vcd");
        $dumpvars(0, tb_immgen);

        // I: zero / positive / sign extension
        check_imm("I value 0", 3'd0, 32'h000FFFFF, 32'h00000000);
        check_imm("I value 10", 3'd0, 32'h00AFFFFF, 32'h0000000A);
        check_imm("I value -2048", 3'd0, 32'h800FFFFF, 32'hFFFFF800);

        // S: split fields / sign extension
        check_imm("S value 12", 3'd1, 32'h01FFF67F, 32'h0000000C);
        check_imm("S value -2048", 3'd1, 32'h81FFF07F, 32'hFFFFF800);

        // B: low zero / relocated bit 11 / sign extension
        check_imm("B value 8", 3'd2, 32'h01FFF47F, 32'h00000008);
        check_imm("B bit 11", 3'd2, 32'h01FFF0FF, 32'h00000800);
        check_imm("B value -4096", 3'd2, 32'h81FFF07F, 32'hFFFFF000);

        // U: low 12 bits cleared / top bit preserved
        check_imm("U value 305418240", 3'd3, 32'h12345FFF, 32'h12345000);
        check_imm("U value 2147483648", 3'd3, 32'h80000FFF, 32'h80000000);

        // J: low zero / relocated bit 11 / sign extension
        check_imm("J value 16", 3'd4, 32'h01000FFF, 32'h00000010);
        check_imm("J bit 11", 3'd4, 32'h00100FFF, 32'h00000800);
        check_imm("J value -1048576", 3'd4, 32'h80000FFF, 32'hFFF00000);

        // Unused selectors: default output is zero
        check_imm("unused select 5", 3'd5, 32'hFFFFFFFF, 32'h00000000);
        check_imm("unused select 6", 3'd6, 32'hFFFFFFFF, 32'h00000000);
        check_imm("unused select 7", 3'd7, 32'hFFFFFFFF, 32'h00000000);

        if (error_count != 0)
            $fatal(1, "%0d of %0d tests failed.", error_count, test_count);
        $display("All %0d tests passed!", test_count);
        $finish;
    end
endmodule
