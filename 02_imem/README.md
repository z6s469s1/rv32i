English | [繁體中文](README.zh-TW.md)

# IMEM

Instruction memory stores program instructions. The PC supplies a byte address through `addr`, and IMEM returns the matching instruction through `instr`.

This module has no clock or write port. It uses a combinational read: when the address changes, the output updates without waiting for a clock edge.

- Circuit diagram

![IMEM](imemv2.png)

- Port Table

| Signal | Direction and width | Purpose |
| --- | --- | --- |
| `addr` | 32-bit input | Byte address from PC |
| `instr` | 32-bit output | Instruction word at the address |

```verilog
module imem #(parameter DEPTH = 256) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
```

# Code

- Declare instruction memory

    ```verilog
    reg [31:0] mem [0:DEPTH-1];
    ```

    `DEPTH` sets the number of instruction entries. Its default is 256. Each entry holds 32 bits, or 4 bytes.

    ```text
    256 entries × 4 bytes = 1024 bytes = 1 KiB (often called 1 KB)
    ```

- Load the program

    ```verilog
    initial $readmemh("program.hex", mem);
    ```

    At the start of simulation, `$readmemh` loads hexadecimal values from `program.hex` into `mem` in order. The relative path is resolved from the simulator's working directory.

- Read an instruction

    ```verilog
    assign instr = mem[addr[31:2]];
    ```

    `addr[31:2]` converts a byte address into an array index. The continuous assignment drives `instr` with the selected memory entry.

- Read examples

    The current `program.hex` contains these four instructions:

    | Byte address `addr` | Array entry | Instruction output `instr` | Instruction |
    | --- | --- | --- | --- |
    | `0x000` | `mem[0]` | `00500093` | `addi x1, x0, 5` |
    | `0x004` | `mem[1]` | `00A00113` | `addi x2, x0, 10` |
    | `0x008` | `mem[2]` | `002081B3` | `add x3, x1, x2` |
    | `0x00C` | `mem[3]` | `00000013` | `nop` (`addi x0, x0, 0`) |

# Questions and Discussion

- Why does dividing the address by 4 give the array index?

    PC addresses count bytes, but each `mem` entry holds 4 bytes. Dividing the byte address by 4 selects the matching entry.

    `addr[31:2]` drops the lowest two bits. For this unsigned address, that is the same as integer division by 4:

    ```text
    addr = 0x000 → index = 0 → mem[0]
    addr = 0x004 → index = 1 → mem[1]
    addr = 0x008 → index = 2 → mem[2]
    addr = 0x00C → index = 3 → mem[3]
    ```

- What happens with an unaligned address?

    The code assumes 4-byte-aligned instruction addresses, so `addr[1:0]` should be `2'b00`. It does not check alignment. Addresses 0, 1, 2, and 3 all select `mem[0]` because the lowest two bits are ignored.

- Does a 32-bit address allow access to more than 1 KB?

    The address width does not determine the actual memory capacity. The default array has only 256 entries, with valid indices from 0 to 255. The byte address range is `0x000` through `0x3FF`, and the last aligned instruction starts at `0x3FC`.

    The code does not check address bounds. For example, `addr = 0x400` selects index 256, which is out of range and returns `x` (unknown) in RTL simulation.
