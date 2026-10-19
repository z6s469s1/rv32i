English | [繁體中文](README.zh-TW.md)

# RV32I ISA and Instruction Formats

An ISA (Instruction Set Architecture) defines the instructions, registers, and instruction behavior available to software. RV32I is the 32-bit base integer instruction set of RISC-V. It specifies execution results; hardware may implement it using a single-cycle, multicycle, or pipelined design.

- **RV**: RISC-V.
- **32**: Integer register width (XLEN) is 32 bits.
- **I**: The base integer instruction set, including integer operations, memory access, branches, and jumps.
- There are 32 integer registers, `x0` through `x31`, each 32 bits wide. `x0` always reads as zero, and writes to it are discarded.
- `pc` holds the address of the current instruction. Every instruction in RV32I alone is 32 bits (4 bytes) long, so sequential execution normally advances to `pc + 4`.
- RV32I uses a load/store architecture: load/store instructions access memory, while arithmetic and logic instructions operate on registers or immediates.

> RV32I has four basic formats, R/I/S/U, plus two immediate-encoding variants, B/J. Tutorials commonly present these as six types. Multiplication/division (M), compressed instructions (C), CSR operations (Zicsr), and `FENCE.I` (Zifencei) belong to separate extensions.

## 1. Instruction Field Comparison

The table lists instruction fields from bit 31 on the left to bit 0 on the right. `imm[n:m]` refers to bit positions in the reconstructed immediate, rather than positions in the instruction itself.

| Type | bit 31:25 | bit 24:20 | bit 19:15 | bit 14:12 | bit 11:7 | bit 6:0 | Common operations and examples |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-type (Register) | `funct7` | `rs2` | `rs1` | `funct3` | `rd` | `opcode` | Register arithmetic, logic, and shifts; `add x3, x1, x2` |
| I-type (Immediate) | `imm[11:5]` | `imm[4:0]` | `rs1` | `funct3` | `rd` | `opcode` | Immediate operations, loads, and indirect jumps; `addi x3, x1, 10`, `lw x3, 8(x1)` |
| S-type (Store) | `imm[11:5]` | `rs2` | `rs1` | `funct3` | `imm[4:0]` | `opcode` | Memory stores; `sw x2, 12(x1)` |
| B-type (Branch) | `imm[12] / imm[10:5]` | `rs2` | `rs1` | `funct3` | `imm[4:1] / imm[11]` | `opcode` | Conditional branches; `beq x1, x2, loop` |
| U-type (Upper Immediate) | `imm[31:25]` | `imm[24:20]` | `imm[19:15]` | `imm[14:12]` | `rd` | `opcode` | Upper constants or PC-relative addresses; `lui x3, 0x12345`, `auipc x3, 0x1` |
| J-type (Jump) | `imm[20] / imm[10:5]` | `imm[4:1] / imm[11]` | `imm[19:15]` | `imm[14:12]` | `rd` | `opcode` | Unconditional direct jumps with return-address linking; `jal x1, func` |

### Field Definitions

| Field | Width | Meaning |
| --- | --- | --- |
| `opcode` | 7 bits | Selects the major instruction class, such as register operations, loads, or branches |
| `rd` | 5 bits | Destination register for the result |
| `rs1` | 5 bits | First source register |
| `rs2` | 5 bits | Second source register |
| `funct3` | 3 bits | Selects an operation within an opcode, such as ADD versus AND |
| `funct7` | 7 bits | Further distinguishes operations, such as ADD versus SUB |
| `imm` | Varies by format | A constant or address offset encoded in the instruction |

A 5-bit register index selects one of 32 registers. Where present, `rs1`, `rs2`, and `rd` occupy fixed positions to simplify decoding. Formats without those fields use the same positions for immediates or other purposes.

## 2. Instruction Types

### R-type: Register-to-Register Operations

Uses two source registers and writes the result to a destination register.

```text
Syntax:   op rd, rs1, rs2
Examples: add x3, x1, x2       # x3 = x1 + x2
          sub x3, x1, x2       # x3 = x1 - x2
```

- Instructions: `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, and `AND`.
- Opcode: `0110011`. `funct3` and `funct7` select the operation.
- There is no immediate. Shift instructions use the lowest 5 bits of the value in `rs2` as the shift amount.
- `SLT` performs a signed comparison; `SLTU` performs an unsigned comparison. Both produce 0 or 1.

### I-type: Immediate Operations, Loads, and Indirect Jumps

Typical I-type instructions use one source register and a 12-bit immediate, writing a result to `rd`. A normal immediate is sign-extended to 32 bits and ranges from -2048 to 2047.

| Class | Instructions | Opcode | Example behavior |
| --- | --- | --- | --- |
| Immediate arithmetic/logic | `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI` | `0010011` | `addi x3, x1, 10` → `x3 = x1 + 10` |
| Immediate shifts | `SLLI`, `SRLI`, `SRAI` | `0010011` | `slli x3, x1, 2` → `x3 = x1 << 2` |
| Loads | `LB`, `LH`, `LW`, `LBU`, `LHU` | `0000011` | `lw x3, 8(x1)` → read 32 bits from address `x1 + 8` into `x3` |
| Indirect jump | `JALR` | `1100111` | `jalr x1, 0(x5)` → save the return address and jump to the address specified by `x5` |

- `LB` and `LH` sign-extend the loaded 8/16-bit value; `LBU` and `LHU` zero-extend it.
- Immediate shifts are special: bits 24:20 contain the 5-bit `shamt` (0–31), and bits 31:25 identify the operation, rather than forming a normal signed 12-bit operand.
- `SLTIU` still sign-extends its immediate before performing an unsigned comparison.
- `JALR` targets `(rs1 + sign-extended imm) & ~1` and writes `pc + 4` to `rd`. Its immediate is in bytes, with no implicit left shift.
- `FENCE` (opcode `0001111`), `ECALL`, and `EBREAK` (opcode `1110011`) also use the I-type encoding layout, but their fields have special meanings rather than representing a normal register-plus-immediate operation.

### S-type: Store Register Data to Memory

Uses `rs1` as the base address and `rs2` as the data to store. The 12-bit immediate is split across two fields.

```text
Syntax:  store rs2, offset(rs1)
Example: sw x2, 12(x1)       # Store 32 bits from x2 at address x1 + 12
```

- Instructions: `SB`, `SH`, and `SW`. Opcode: `0100011`.
- They store the lowest 8, 16, or 32 bits of `rs2`, respectively.
- The effective address is `rs1 + sign-extended imm`. The offset ranges from -2048 to 2047 bytes.
- There is no `rd`, and no result is written to an integer register.

### B-type: Conditional Branches

Compares `rs1` with `rs2` and changes `pc` only when the condition is true. The branch target is the address of the current branch instruction plus the offset.

```text
Examples: beq x1, x2, loop    # Jump to loop if x1 == x2
          bne x1, x2, loop    # Jump to loop if x1 != x2
```

| Instruction | Branch condition |
| --- | --- |
| `BEQ` / `BNE` | Equal / not equal |
| `BLT` / `BGE` | Signed less than / greater than or equal |
| `BLTU` / `BGEU` | Unsigned less than / greater than or equal |

- Opcode: `1100011`. There is no `rd`, and no return address is saved.
- The reconstructed offset is a signed 13-bit value with bit 0 fixed to zero. The encoding covers -4096 to 4094 bytes in steps of 2 bytes.
- If the condition is false, execution continues at `pc + 4`.
- Although the encoding supports 2-byte steps, RV32I alone requires 4-byte instruction alignment. A taken branch to a misaligned address raises an instruction-address-misaligned exception.

### U-type: Upper Immediates

Carries a 20-bit immediate that occupies result bits 31:12, with the lowest 12 bits set to zero.

| Instruction | Opcode | Behavior |
| --- | --- | --- |
| `LUI` | `0110111` | `rd = imm20 << 12` |
| `AUIPC` | `0010111` | `rd = pc + (imm20 << 12)`, using the address of this instruction |

```text
Examples: lui x3, 0x12345     # x3 = 0x12345000
          auipc x3, 0x1      # x3 = this instruction's pc + 0x00001000
```

There are no `rs1`, `rs2`, or funct fields. `LUI` is often combined with `ADDI` to construct a full 32-bit constant. `AUIPC` can be combined with a load/store or `JALR` to form a pc-relative address.

### J-type: Unconditional Direct Jumps

`JAL` uses J-type to jump to a pc-relative target and optionally save a return address.

```text
Syntax:   jal rd, label
Examples: jal x1, func        # x1 = pc + 4; jump to func
          jal x0, loop       # Jump to loop; discard the return address via x0
```

- Opcode: `1101111`. There are no `rs1`, `rs2`, or funct fields.
- The reconstructed offset is a signed 21-bit value with bit 0 fixed to zero.
- The encoding covers -1,048,576 to 1,048,574 bytes in steps of 2 bytes.
- The target is `pc + offset`, and `rd` receives `pc + 4`. RV32I alone still requires 4-byte target alignment.
- The assembly pseudoinstruction `j label` expands to `jal x0, label`. The common `ret` pseudoinstruction expands to the I-type instruction `jalr x0, 0(x1)`.

## 3. Immediate Reconstruction and Verilog Decoding

B/J-type immediate bits are not stored in consecutive numerical order. Decoding reconstructs the offset, inserts the fixed low zero bit, and sign-extends the result. Below, `instr` is a 32-bit instruction, and every `imm_*` signal is the reconstructed 32-bit bit pattern.

```verilog
wire [6:0] opcode = instr[6:0];
wire [4:0] rd     = instr[11:7];
wire [2:0] funct3 = instr[14:12];
wire [4:0] rs1    = instr[19:15];
wire [4:0] rs2    = instr[24:20];
wire [6:0] funct7 = instr[31:25];

wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7],
                     instr[30:25], instr[11:8], 1'b0};
wire [31:0] imm_u = {instr[31:12], 12'b0};
wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                     instr[20], instr[30:21], 1'b0};
```

These wires only extract bits. The control unit must still decode `opcode`, `funct3`, and, where needed, `funct7`, validate the encoding, and select the appropriate fields. For example, `instr[11:7]` in a store instruction holds immediate bits rather than a destination register.

| Type | Source registers | Destination register | Main immediate purpose |
| --- | --- | --- | --- |
| R | `rs1`, `rs2` | `rd` | None |
| I | Usually `rs1` | Usually `rd` | Operand, load offset, or JALR offset; special instructions have separate definitions |
| S | `rs1`, `rs2` | None | Store offset |
| B | `rs1`, `rs2` | None | pc-relative conditional branch offset |
| U | None | `rd` | Upper 20-bit constant or pc-relative address |
| J | None | `rd` | pc-relative direct jump offset |

## References

- [RISC-V Official Specification: RV32I Base Integer Instruction Set](https://docs.riscv.org/reference/isa/unpriv/rv32)
- [RISC-V Official Instruction Encoding Listings](https://docs.riscv.org/reference/isa/unpriv/rv-32-64g.html)
