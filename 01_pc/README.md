English | [繁體中文](README.zh-TW.md)

# PC

The PC (Program Counter) stores the instruction address. This module is a 32-bit register. At each rising clock edge, it either clears to zero or loads `next_pc`, depending on `rst`.

- Circuit diagram

![PC](pc.png)

- Port Table

| Signal | Direction and width | Purpose |
| --- | --- | --- |
| `clk` | 1-bit input | Triggers updates on the rising edge |
| `rst` | 1-bit input | Clears PC on the rising edge when high |
| `next_pc` | 32-bit input | Address to load at the next rising edge |
| `pc` | 32-bit output | Current stored instruction address |

```verilog
module pc
(
    input wire clk,
    input wire rst,
    input wire [31:0] next_pc,
    output reg [31:0] pc
);
```

# Code

- Update PC at the rising edge

    ```verilog
    always @(posedge clk) begin
        if (rst)
            pc <= 32'h0000_0000;
        else
            pc <= next_pc;
    end
    ```

- Update examples

    | Rising clock edge | `rst` | `next_pc` | Updated `pc` |
    | --- | --- | --- | --- |
    | First | 1 | `32'h0000_0100` | `32'h0000_0000` |
    | Second | 0 | `32'h0000_0004` | `32'h0000_0004` |
    | Third | 0 | `32'h0000_0008` | `32'h0000_0008` |

# Questions and Discussion

- Who calculates the next address?

    This module only stores the address. **It does not calculate `pc + 4`.** External logic must calculate the next address and supply it through `next_pc`.

    For the current 32-bit, 4-byte instructions, sequential execution normally uses `pc + 4`. A branch or jump may select a target address instead. This address calculation and selection logic is outside `pc.v`.

- Why does the testbench need `#1`?

    `tb_pc.v` waits briefly after the rising clock edge before checking PC:

    ```verilog
    @(posedge clk);
    #1;
    check_pc(pc, expected_pc);
    ```

    **`#1` lets the output update before the testbench checks it. Real hardware can have a similar problem: sampling data before it is ready. If data is not stable early enough before the sampling clock edge, a setup timing violation occurs.**

    The causes are different. Here, the testbench has not waited for the simulator's NBA update. In hardware, data takes time to travel through registers, logic, and wires, and may arrive too late. `#1` fixes when the testbench observes the output. Hardware must meet setup requirements through a suitable clock period and data path design.

    PC uses a nonblocking assignment (`<=`):

    ```verilog
    always @(posedge clk) begin
        if (rst)
            pc <= 32'h0000_0000;
        else
            pc <= next_pc;
    end
    ```

    At the rising edge, both the DUT and the testbench run. The DUT evaluates the right-hand side and schedules the PC update for the NBA (Nonblocking Assignment) phase at the same simulation time. An immediate call to `check_pc` reads the old PC.

    ```text
    Rising clock edge
      → DUT calculates and schedules the PC update
      → An immediate TB check reads the old PC
      → PC updates in the NBA phase
      → After #1, the TB checks the new PC
    ```

- Setup timing violation

    ![Setup timing](setup_timing.png)

    Reference: https://medium.com/@aiclab.official/clock-to-q-modeling-why-non-blocking-assignments-matter-1b83c9e253b8
