[English](README.md) | 繁體中文

# RV32I ISA 與指令格式

ISA（Instruction Set Architecture，指令集架構）定義軟體可使用的指令、暫存器及各指令的行為。RV32I 是 RISC-V 的 32-bit 基礎整數指令集；ISA 定義程式執行的結果，實際電路可以採用單週期、多週期或管線等實作。

- **RV**：RISC-V。
- **32**：整數暫存器寬度（XLEN）為 32 bits。
- **I**：基礎整數指令集，包含整數運算、記憶體存取、分支與跳躍等操作。
- 有 32 個整數暫存器 `x0`～`x31`，每個為 32 bits；`x0` 永遠讀出 0，寫入結果會被丟棄。
- `pc` 保存目前指令的位址。純 RV32I 的每條指令固定為 32 bits（4 bytes），一般依序執行時下一個位址為 `pc + 4`。
- RV32I 是 load/store 架構：透過 load/store 存取記憶體，算術與邏輯指令使用暫存器或立即數。

> RV32I 有四種基本格式 R、I、S、U，以及立即數編碼的變體 B、J。教學上通常將它們並列成以下六種 type。乘除法（M）、壓縮指令（C）、CSR（Zicsr）及 `FENCE.I`（Zifencei）屬於其他擴充。

## 1. 各 type 欄位比較圖

以下由左到右對應指令的 bit 31 到 bit 0。`imm[n:m]` 指的是「重組後立即數」的位元編號，不是指令本身的位元位置。

| Type | bit 31:25 | bit 24:20 | bit 19:15 | bit 14:12 | bit 11:7 | bit 6:0 | 常見操作與範例 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-type (Register) | `funct7` | `rs2` | `rs1` | `funct3` | `rd` | `opcode` | 暫存器算術、邏輯與位移；`add x3, x1, x2` |
| I-type (Immediate) | `imm[11:5]` | `imm[4:0]` | `rs1` | `funct3` | `rd` | `opcode` | 立即數運算、載入與間接跳躍；`addi x3, x1, 10`、`lw x3, 8(x1)` |
| S-type (Store) | `imm[11:5]` | `rs2` | `rs1` | `funct3` | `imm[4:0]` | `opcode` | 記憶體寫入；`sw x2, 12(x1)` |
| B-type (Branch) | `imm[12] / imm[10:5]` | `rs2` | `rs1` | `funct3` | `imm[4:1] / imm[11]` | `opcode` | 條件分支；`beq x1, x2, loop` |
| U-type (Upper Immediate) | `imm[31:25]` | `imm[24:20]` | `imm[19:15]` | `imm[14:12]` | `rd` | `opcode` | 建立高位常數或 PC 相對位址；`lui x3, 0x12345`、`auipc x3, 0x1` |
| J-type (Jump) | `imm[20] / imm[10:5]` | `imm[4:1] / imm[11]` | `imm[19:15]` | `imm[14:12]` | `rd` | `opcode` | 無條件直接跳躍並保存返回位址；`jal x1, func` |

### 欄位的意義

| 欄位 | 寬度 | 說明 |
| --- | --- | --- |
| `opcode` | 7 bits | 決定主要指令類別，例如暫存器運算、load 或 branch |
| `rd` | 5 bits | 目的暫存器（destination register），用來寫回結果 |
| `rs1` | 5 bits | 第一個來源暫存器（source register 1） |
| `rs2` | 5 bits | 第二個來源暫存器（source register 2） |
| `funct3` | 3 bits | 配合 opcode 區分操作，例如 ADD 與 AND |
| `funct7` | 7 bits | 進一步區分操作，例如 ADD 與 SUB |
| `imm` | 依格式而定 | 編碼在指令內的常數或位址偏移量（immediate） |

5-bit 暫存器索引可以選擇 32 個暫存器。當格式具有 `rs1`、`rs2`、`rd` 時，它們的位置固定，便於解碼；沒有該欄位的格式，則將位置交給立即數等其他用途。

## 2. 各 type 介紹

### R-type：暫存器對暫存器運算

使用兩個來源暫存器，將結果寫入目的暫存器。

```text
語法：op rd, rs1, rs2
範例：add x3, x1, x2       # x3 = x1 + x2
      sub x3, x1, x2       # x3 = x1 - x2
```

- 指令：`ADD`、`SUB`、`SLL`、`SLT`、`SLTU`、`XOR`、`SRL`、`SRA`、`OR`、`AND`。
- opcode 為 `0110011`，由 `funct3` 和 `funct7` 決定實際運算。
- 沒有立即數。位移指令使用 `rs2` 值的最低 5 bits 作為位移量。
- `SLT` 使用有號比較，`SLTU` 使用無號比較；結果為 0 或 1。

### I-type：立即數運算、load 與間接跳躍

一般 I-type 使用一個來源暫存器及 12-bit 立即數，並寫入 `rd`。一般立即數先符號延伸為 32 bits，數值範圍為 -2048～2047。

| 類別 | 指令 | opcode | 行為範例 |
| --- | --- | --- | --- |
| 立即數運算 | `ADDI`、`SLTI`、`SLTIU`、`XORI`、`ORI`、`ANDI` | `0010011` | `addi x3, x1, 10` → `x3 = x1 + 10` |
| 立即數位移 | `SLLI`、`SRLI`、`SRAI` | `0010011` | `slli x3, x1, 2` → `x3 = x1 << 2` |
| Load | `LB`、`LH`、`LW`、`LBU`、`LHU` | `0000011` | `lw x3, 8(x1)` → 從位址 `x1 + 8` 讀取 32 bits 至 `x3` |
| 間接跳躍 | `JALR` | `1100111` | `jalr x1, 0(x5)` → 保存返回位址並跳至 `x5` 指定的位置 |

- `LB`、`LH` 將讀出的 8/16-bit 資料符號延伸；`LBU`、`LHU` 則補 0。
- 位移立即數是特例：bit 24:20 為 5-bit `shamt`（0～31），bit 31:25 用來辨別操作，不是一般的 12-bit 有號運算元。
- `SLTIU` 的立即數仍先符號延伸，再進行無號比較。
- `JALR` 的目標為 `(rs1 + 符號延伸後的 imm) & ~1`，`rd` 寫入 `pc + 4`；立即數以 byte 為單位，不做隱含左移。
- `FENCE`（opcode `0001111`）及 `ECALL`、`EBREAK`（opcode `1110011`）也使用 I-type 編碼配置，但相關欄位有特殊定義，不能解讀成一般的暫存器加立即數運算。

### S-type：Store，將暫存器資料寫入記憶體

使用 `rs1` 當基底位址、`rs2` 當要寫入的資料，12-bit 立即數分成兩段存放。

```text
語法：store rs2, offset(rs1)
範例：sw x2, 12(x1)       # 將 x2 的 32-bit 資料寫到位址 x1 + 12
```

- 指令：`SB`、`SH`、`SW`；opcode 為 `0100011`。
- 分別寫入 `rs2` 的最低 8、16、32 bits。
- 有效位址為 `rs1 + 符號延伸後的 imm`，offset 範圍為 -2048～2047 bytes。
- 沒有 `rd`，不會將結果寫回整數暫存器。

### B-type：條件分支

比較 `rs1` 與 `rs2`，條件成立才修改 `pc`。分支目標是「目前這條分支指令的位址 + offset」。

```text
範例：beq x1, x2, loop    # x1 == x2 時跳到 loop
      bne x1, x2, loop    # x1 != x2 時跳到 loop
```

| 指令 | 跳躍條件 |
| --- | --- |
| `BEQ` / `BNE` | 相等 / 不相等 |
| `BLT` / `BGE` | 有號小於 / 大於等於 |
| `BLTU` / `BGEU` | 無號小於 / 大於等於 |

- opcode 為 `1100011`，沒有 `rd`，不保存返回位址。
- offset 重組後為 13-bit 有號值，最低 bit 固定為 0，編碼範圍為 -4096～4094 bytes，間隔為 2 bytes。
- 條件不成立時，下一條指令為 `pc + 4`。
- 雖然編碼可表示 2-byte 間隔，純 RV32I 的指令位址仍須 4-byte 對齊；成立的分支若跳到未對齊位址，會觸發指令位址未對齊例外。

### U-type：建立高位立即數

指令內帶有 20-bit 立即數，放到結果的 bit 31:12，低 12 bits 補 0。

| 指令 | opcode | 行為 |
| --- | --- | --- |
| `LUI` | `0110111` | `rd = imm20 << 12` |
| `AUIPC` | `0010111` | `rd = pc + (imm20 << 12)`，pc 為此指令位址 |

```text
範例：lui x3, 0x12345     # x3 = 0x12345000
      auipc x3, 0x1      # x3 = 此指令的 pc + 0x00001000
```

沒有 `rs1`、`rs2` 或 funct 欄位。`LUI` 常搭配 `ADDI` 建立完整的 32-bit 常數；`AUIPC` 可搭配 load/store 或 `JALR` 形成相對於 pc 的位址。

### J-type：無條件直接跳躍

`JAL` 使用 J-type，跳到相對於目前 pc 的目標，同時可保存返回位址。

```text
語法：jal rd, label
範例：jal x1, func        # x1 = pc + 4，跳到 func
      jal x0, loop       # 跳到 loop，返回位址寫到 x0 後被丟棄
```

- opcode 為 `1101111`，沒有 `rs1`、`rs2` 或 funct 欄位。
- offset 重組後為 21-bit 有號值，最低 bit 固定為 0。
- 編碼範圍為 -1,048,576～1,048,574 bytes，間隔為 2 bytes。
- 目標為 `pc + offset`，`rd` 寫入 `pc + 4`。純 RV32I 的跳躍目標仍須 4-byte 對齊。
- 組合語言中的 `j label` 是 `jal x0, label` 的虛擬指令；常見的 `ret` 則是 I-type 的 `jalr x0, 0(x1)`。

## 參考資料

- [RISC-V 官方規格：RV32I Base Integer Instruction Set](https://docs.riscv.org/reference/isa/unpriv/rv32)
- [RISC-V 官方指令編碼表](https://docs.riscv.org/reference/isa/unpriv/rv-32-64g.html)
