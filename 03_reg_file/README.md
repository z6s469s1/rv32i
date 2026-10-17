English | [繁體中文](README.zh-TW.md)

# Register File

The register file stores data used by CPU operations. This module contains the 32 RV32I integer registers, `x0` through `x31`. Each register holds 32 bits.

It has two read ports and one write port. It can read two registers at once and write one register at a rising clock edge. Reads use combinational logic and do not wait for a clock edge.

- Circuit diagram

![Register File](RegFile.png)

- Port Table

| Signal | Direction and width | Purpose |
| --- | --- | --- |
| `clk` | 1-bit input | Triggers writes on the rising edge |
| `we` | 1-bit input | Write enable; high allows a write |
| `waddr` | 5-bit input | Destination register number, corresponding to `rd` |
| `wdata` | 32-bit input | Data to write |
| `raddr1` | 5-bit input | First source register number, corresponding to `rs1` |
| `raddr2` | 5-bit input | Second source register number, corresponding to `rs2` |
| `rdata1` | 32-bit output | Data from the first read port |
| `rdata2` | 32-bit output | Data from the second read port |

```verilog
module reg_file
(
    input wire clk,
    input wire we,
    input wire [4:0] waddr,
    input wire [31:0] wdata,
    input wire [4:0] raddr1,
    input wire [4:0] raddr2,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2
);
```

## Common Register Uses

The following table follows the standard ABI (Application Binary Interface). ABI names are aliases: for example, `ra` is `x1`. Except for `x0`, which always reads as zero, these roles are mainly software conventions. This register file does not perform these tasks automatically.

| Register | ABI name | Common use | Preservation across calls |
| --- | --- | --- | --- |
| `x0` | `zero` | Constant zero; writes are ignored | Always zero |
| `x1` | `ra` | Return address | Caller |
| `x2` | `sp` | Stack pointer | Callee must restore |
| `x3` | `gp` | Global pointer for accessing global data | Reserved; do not freely change |
| `x4` | `tp` | Thread pointer for accessing thread data | Reserved; do not freely change |
| `x5` | `t0` | Temporary data | Caller |
| `x6` | `t1` | Temporary data | Caller |
| `x7` | `t2` | Temporary data | Caller |
| `x8` | `s0 / fp` | Saved data; optional frame pointer | Callee |
| `x9` | `s1` | Data kept across function calls | Callee |
| `x10` | `a0` | Argument 1; also return values | Caller |
| `x11` | `a1` | Argument 2; also return values | Caller |
| `x12` | `a2` | Argument 3 | Caller |
| `x13` | `a3` | Argument 4 | Caller |
| `x14` | `a4` | Argument 5 | Caller |
| `x15` | `a5` | Argument 6 | Caller |
| `x16` | `a6` | Argument 7 | Caller |
| `x17` | `a7` | Argument 8 | Caller |
| `x18` | `s2` | Data kept across function calls | Callee |
| `x19` | `s3` | Data kept across function calls | Callee |
| `x20` | `s4` | Data kept across function calls | Callee |
| `x21` | `s5` | Data kept across function calls | Callee |
| `x22` | `s6` | Data kept across function calls | Callee |
| `x23` | `s7` | Data kept across function calls | Callee |
| `x24` | `s8` | Data kept across function calls | Callee |
| `x25` | `s9` | Data kept across function calls | Callee |
| `x26` | `s10` | Data kept across function calls | Callee |
| `x27` | `s11` | Data kept across function calls | Callee |
| `x28` | `t3` | Temporary data | Caller |
| `x29` | `t4` | Temporary data | Caller |
| `x30` | `t5` | Temporary data | Caller |
| `x31` | `t6` | Temporary data | Caller |

“Caller” means that the calling function must save the old value if it needs it after the call. The called function may overwrite it. “Callee” means that a function must restore the original value before returning if it uses that register. Software normally saves and restores values through the stack; the register file does not make backups automatically.

Actual argument placement depends on data types and sizes; argument numbers in the table are a simplified guide. The optional `fp` points to the current function's stack frame. PC is separate and is not part of `x0` through `x31`.

Reference: [RISC-V ABI register conventions](https://docs.riscv.org/reference/abi/v1.0/riscv-cc-register-convention.html).

# Code

- Declare the register array

    ```verilog
    reg [31:0] registers [0:31];
    ```

    `[31:0]` gives each entry 32 bits. `[0:31]` provides 32 entries, indexed directly by register number.

    ```text
    32 entries × 32 bits = 1024 bits = 128 bytes
    ```

    This is the declared array capacity. Since `x0` always reads as zero, synthesis may remove storage that is not needed.

- Initialize the registers

    ```verilog
    initial begin
        for (integer i = 0; i < 32; i = i + 1) begin
            registers[i] <= 32'h0000_0000;
        end
    end
    ```

    At the start of simulation, all registers are set to zero. The loop contains no timing controls, so it does not take 32 clock cycles. These nonblocking assignments update in the NBA phase at the starting simulation time.

- Write at the rising edge

    ```verilog
    always @(posedge clk) begin
        if (we && waddr != 5'h0) begin
            registers[waddr] <= wdata;
        end
    end
    ```

    At each rising edge, if `we = 1` and the destination is not `x0`, the module writes `wdata` into `registers[waddr]`. Otherwise, the stored data stays unchanged.

    `<=` is a nonblocking assignment. It samples the right-hand side at the rising edge and updates the register in the NBA phase at the same simulation time.

- Read two registers

    ```verilog
    assign rdata1 = raddr1 == 5'h0 ? 32'h0000_0000 : registers[raddr1];
    assign rdata2 = raddr2 == 5'h0 ? 32'h0000_0000 : registers[raddr2];
    ```

    `condition ? A : B` selects A when the condition is true, or B otherwise. Register number 0 returns zero directly. Other numbers return the selected array entry.

    The read ports select their data independently. They can read different registers or the same register. The outputs update when the read addresses or selected data change.

- Read and write examples

    The current `tb_reg_file.v` includes these tests:

    | Operation | Condition | Expected result |
    | --- | --- | --- |
    | Write `x1` | At rising edge: `we = 1`, `waddr = 5'h1`, `wdata = 32'h0000_0001` | `x1` becomes 1 |
    | Write `x31` | At rising edge: `we = 1`, `waddr = 5'h1F`, `wdata = 32'h0000_0020` | `x31` becomes decimal 32 |
    | Read both | `raddr1 = 5'h1`, `raddr2 = 5'h1F` | Outputs are 1 and 32 |
    | Try writing `x0` | At rising edge: `we = 1`, `waddr = 0`, `wdata = 32'hFFFF_FFFF` | Write is ignored; `x0` still reads as zero |

# Questions and Discussion

- Why are register addresses only 5 bits wide?

    Five bits represent 0 through 31, enough to select all 32 registers. These are register numbers, not byte addresses, so there is no need to divide by 4 as in IMEM.

- Why are writes to `x0` ignored?

    RV32I requires `x0` to always read as zero. The code blocks writes to `x0` and directly returns zero when the read address is 0. It therefore does not depend on the stored value of `registers[0]`.

- Why is there no `rst`? Is `initial` the same as reset?

    This module has no reset port. Its `initial` block clears the array once at the start of simulation and cannot be triggered again during execution. RV32I does not require `x1` through `x31` to be zero after reset. Clearing them is an implementation choice; `x0` must always read as zero.

    Whether `initial` can become hardware initialization depends on the synthesis tool and target device. Values seen at simulation startup are not automatically guaranteed on all hardware.

- What happens when reading and writing the same register?

    For a register other than `x0`, the read port shows the old data before the write edge. After the rising edge, it shows the new data once the NBA write and combinational updates finish. A check immediately at the rising edge may still see the old value.
