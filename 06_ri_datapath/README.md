English | [繁體中文](README.zh-TW.md)

# R/I Datapath

This chapter focuses on the new Control Unit, PC adder, and instruction parser. They connect the PC, IMEM, Register File, ImmGen, and ALU from earlier chapters into a single-cycle datapath supporting R-type and I-type ALU instructions.

The PC adder generates the next sequential address, and the parser splits the instruction into fields. The Control Unit uses those fields to select the ALU operation and coordinate the Register File and ImmGen with the ALU. PC and Register File writes update at rising edges; the remaining paths use combinational logic.

- Circuit diagram

![R/I Datapath](ri_datapath.png)

## New Logic and Data Flow

| New component | Location | Purpose |
| --- | --- | --- |
| PC adder | `assign next_pc` in `core_ri.v` | Computes `pc + 4` using combinational logic |
| Instruction parser | Decode section in `core_ri.v` | Extracts fields for the controller and register file |
| Control Unit | `control.v`, instance `ctrl` | Decodes R/I ALU instructions into datapath control signals |
| ALUSrc MUX | `wire [31:0] alu_b = alu_src ? imm : rdata2` in `core_ri.v` | Selects ALU operand B using `alu_src`: 0 selects register data `rdata2` (R-type); 1 selects immediate `imm` (I-type ALU) |

## Control Unit

`control.v` is a combinational decoder with no clock or internal state. It first uses `opcode` to distinguish R-type from I-type ALU instructions, then selects the operation using `funct3` and `funct7`. The parser extracts bits; the controller determines what operation they request.

| Signal | Direction and width | Purpose |
| --- | --- | --- |
| `opcode` | 7-bit input | Selects the major instruction class |
| `funct3` | 3-bit input | Selects arithmetic, logic, comparison, or shift operations |
| `funct7` | 7-bit input | Currently uses bit 5 to distinguish ADD/SUB and SRL/SRA |
| `reg_write` | 1-bit output | Connects to Register File `we` |
| `alu_src` | 1-bit output | 0 selects `rdata2`; 1 selects `imm` as ALU operand B |
| `alu_op` | 4-bit output | Selects the ALU operation; an internal control encoding, not an opcode |
| `imm_sel` | 3-bit output | Selects the ImmGen format; this datapath uses `000` (I-type) |

```verilog
control ctrl (
    .opcode(opcode), .funct3(funct3), .funct7(funct7),
    .reg_write(reg_write), .alu_src(alu_src),
    .alu_op(alu_op), .imm_sel(imm_sel)
);
```

### Instruction Classes and Control Outputs

| Instruction class | `opcode` | `reg_write` | `alu_src` | `imm_sel` | ALU operand B |
| --- | --- | --- | --- | --- | --- |
| R-type ALU | `0110011` | 1 | 0 | `x` (unused) | `rdata2` |
| I-type ALU | `0010011` | 1 | 1 | `000` (I-type) | `imm` |

| Operation | `alu_op` |
| --- | --- |
| ADD / ADDI | `0000` |
| SUB | `0001` |
| AND / ANDI | `0010` |
| OR / ORI | `0011` |
| XOR / XORI | `0100` |
| SLT / SLTI | `0101` |
| SLTU / SLTIU | `0110` |
| SLL / SLLI | `0111` |
| SRL / SRLI | `1000` |
| SRA / SRAI | `1001` |

The controller uses `{funct7[5], funct3}` for R-type operations and `funct3` for I-type operations; immediate right shifts also use `funct7[5]`. Shift amounts come from the lowest 5 bits of ALU operand B. See the [ISA formats](../00_isa/README.md) and [ALU](../04_alu/README.md).

This is a partial datapath: loads, stores, branches, jumps, LUI, and AUIPC are not implemented.

### Decode Examples and Defaults

- `add x3, x1, x2`: opcode `0110011` selects `rdata2`, sets `alu_op = 0000`, and enables write-back.
- `sub x4, x1, x2`: also R-type, but `funct7[5] = 1` and `funct3 = 000` select `alu_op = 0001`.
- `addi x1, x0, 5`: opcode `0010011` selects the I-type immediate 5, sets `alu_op = 0000`, and enables write-back.

At the start of `always @(*)`, defaults set `reg_write = 0`, `alu_src = 0`, `alu_op = 0000`, and `imm_sel = 000`. Instruction decoding then overrides them. Every path has defined outputs, avoiding latches. Unknown opcodes leave writes disabled; this is not complete illegal-instruction validation.

## PC Adder

```verilog
wire [31:0] pc, next_pc, instr;
assign next_pc = pc + 32'd4;
pc pc_reg (.clk(clk), .rst(rst), .next_pc(next_pc), .pc(pc));
```

Each instruction in RV32I alone is 32 bits, or 4 bytes, so byte addresses advance as `0 → 4 → 8 → 12`. The adder continuously computes `next_pc` without a clock. The `pc_reg` instance stores the new value at the rising edge; when `rst = 1`, that edge sets PC to zero instead.

This adder is separate combinational logic from the instruction ALU, allowing next-address and instruction-result calculations in parallel. There is no branch/jump PC selector yet, so PC always takes `pc + 4` outside reset. IMEM uses `pc[31:2]` to convert the byte address into a word index.

## Instruction Parser

```verilog
wire [6:0] opcode = instr[6:0];
wire [4:0] rd     = instr[11:7];
wire [2:0] funct3 = instr[14:12];
wire [4:0] rs1    = instr[19:15];
wire [4:0] rs2    = instr[24:20];
wire [6:0] funct7 = instr[31:25];
```

These are wires and continuous connections inside `core_ri.v`, not a separate module, and require no clock. Here, `wire ... = ...` continuously follows the instruction field rather than capturing it only once at simulation startup.

| Field | Instruction bits | Destination |
| --- | --- | --- |
| `opcode` | `[6:0]` | Control Unit: instruction class |
| `rd` | `[11:7]` | Register File `waddr`: write-back destination |
| `funct3` | `[14:12]` | Control Unit: operation selection |
| `rs1` | `[19:15]` | Register File `raddr1`: first source |
| `rs2` | `[24:20]` | Register File `raddr2`: second source |
| `funct7` | `[31:25]` | Control Unit: further operation selection |

For I-type, bits `[24:20]` actually belong to the immediate. The parser still connects them to `rs2`, but `alu_src = 1` selects `imm`, so the second read port does not supply the ALU operand. Likewise, upper I-type bits generally contain immediate data; shift instructions use operation-encoding bits there. The full `instr` also feeds ImmGen, which reconstructs immediates separately from the parser.

# Code

- Select the next PC and ALU operand, then write back

    ```verilog
    assign next_pc = pc + 32'd4;
    wire [31:0] alu_b = alu_src ? imm : rdata2;
    assign wb_data = alu_result;
    ```

    In one execution cycle, the current PC selects the instruction, register operands are read, and the ALU computes the result. At the next rising edge, the result is written to `rd` and PC advances. Nonblocking assignments (`<=`) update state after the edge; waveform values settle after the combinational logic responds.

- Test program

    `program.hex` contains the following eight instruction words. IMEM uses `pc[31:2]` as the word index, so addresses advance by 4 bytes.

    | PC | Machine code | Instruction | Expected result |
    | --- | --- | --- | --- |
    | 0x00 | `00500093` | `addi x1, x0, 5` | `x1 = 5` |
    | 0x04 | `00A00113` | `addi x2, x0, 10` | `x2 = 10` |
    | 0x08 | `002081B3` | `add x3, x1, x2` | `x3 = 15` |
    | 0x0C | `40208233` | `sub x4, x1, x2` | `x4 = 0xFFFFFFFB` (-5) |
    | 0x10 | `0020F2B3` | `and x5, x1, x2` | `x5 = 0` |
    | 0x14 | `0020E333` | `or x6, x1, x2` | `x6 = 15` |
    | 0x18 | `00000013` | `addi x0, x0, 0` (NOP) | `x0 = 0` |
    | 0x1C | `00000013` | `addi x0, x0, 0` (NOP) | `x0 = 0` |

- Test examples

    `tb_core_ri.v` generates a 10 ns clock, applies reset, waits for eight rising edges, then waits 1 ns before checking `x1` through `x6` through `dut.rf.registers[...]`. The extra delay lets register writes settle. These are six result checks, covering ADDI, ADD, SUB, AND, and OR; the other supported ALU instructions are not exercised by this program.

# Questions and Discussion

- None yet.
