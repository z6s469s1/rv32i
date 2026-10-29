[English](README.md) | 繁體中文

# R/I/S/B Datapath

本章在 [R/I/S datapath](../07_ris_datapath/README.zh-TW.md) 上加入 B-type 條件分支，支援 BEQ、BNE、BLT、BGE、BLTU 與 BGEU。新增 Branch Unit、分支目標位址加法器與 PC MUX，讓 PC 能依比較結果選擇循序執行或跳轉。



- 電路圖

![R/I/S/B Datapath](risb_datapath.png)

## 新增邏輯與資料流

| 新增部分 | 所在位置 | 功能 |
| --- | --- | --- |
| Branch Unit | `branch_unit.v`，instance `bu` | 依 `funct3` 與比較旗標判斷條件，計算 `pc + b_imm` |
| Control Unit 擴充 | `control.v` 的 `B` 分支 | 解碼 branch opcode，輸出 `is_branch` 並選擇 SUB 與 B-type 立即數 |
| ALU 比較旗標 | `alu.v` | 提供相等、signed 小於與 unsigned 小於的比較結果 |
| B-type 立即數路徑 | `immgen.v`，`imm_sel = 010` | 重組分散的立即數位元並符號延伸 |
| PC MUX | `core_risb.v` 的 `assign next_pc` | 選擇分支目標或 `pc + 4` |

一次分支執行中，Register File 讀出 `rs1`、`rs2`，ALU 產生比較旗標；同時 ImmGen 重組位移，Branch Unit 計算目標。組合邏輯決定 `next_pc`，PC 在下一個上升緣更新，分支不寫入暫存器或 DMEM。

## Branch Unit

- Port Table

| 訊號 | 方向與寬度 | 功能 |
| --- | --- | --- |
| `funct3` | 3-bit 輸入 | 選擇分支條件 |
| `zero` | 1-bit 輸入 | ALU 減法結果為零，即 `rs1 == rs2` |
| `alu_lt` | 1-bit 輸入 | `rs1 < rs2`，signed 比較 |
| `alu_ltu` | 1-bit 輸入 | `rs1 < rs2`，unsigned 比較 |
| `pc` | 32-bit 輸入 | 目前分支指令的 byte 位址 |
| `b_imm` | 32-bit 輸入 | 已符號延伸的 byte 位移 |
| `branch_taken` | 1-bit 輸出 | 比較條件是否成立；使用時仍需搭配 `is_branch` |
| `branch_target` | 32-bit 輸出 | `pc + b_imm` |

| 指令 | `funct3` | 跳轉條件 | 使用旗標 |
| --- | --- | --- | --- |
| BEQ | `000` | `rs1 == rs2` | `zero` |
| BNE | `001` | `rs1 != rs2` | `~zero` |
| BLT | `100` | signed `rs1 < rs2` | `alu_lt` |
| BGE | `101` | signed `rs1 >= rs2` | `~alu_lt` |
| BLTU | `110` | unsigned `rs1 < rs2` | `alu_ltu` |
| BGEU | `111` | unsigned `rs1 >= rs2` | `~alu_ltu` |

其餘 `funct3` 令 `branch_taken = 0`。Branch Unit 本身沒有 clock，也沒有 opcode 輸入；它只判斷條件，是否為分支由 Control Unit 決定。

## Control Unit 新增部分

B-type 的 opcode 為 `1100011`。`is_branch` 預設為 0，只在 `B` 分支設為 1，避免 ADDI、NOP 等具有相同 `funct3` 的指令誤觸發跳轉。

| 指令類別 | `reg_write` | `alu_src` | `imm_sel` | `alu_op` | `mem_write` | `wb_sel` | `is_branch` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| B-type | 0 | 0 | `010` (B) | `0001` (SUB) | 0 | 0 | 1 |

`alu_src = 0` 讓 ALU 比較兩個暫存器，而不是將 B-type 立即數當成第二運算元。立即數另送至 Branch Unit 計算目標。`wb_sel` 不影響分支結果，因為 `reg_write = 0`。

## ALU 比較旗標

```verilog
zero = (result == 32'h0000_0000) ? 1'b1 : 1'b0;
alu_lt = ($signed(a) < $signed(b));
alu_ltu = (a < b);
```

分支時 ALU 執行 SUB，因此 `zero` 可判斷相等。Signed 與 unsigned 小於則直接比較運算元：只看 32-bit 減法結果的正負會受到 signed overflow 影響，而 unsigned 結果與零比較無法判斷借位。

例如 `0xFFFFFFFF` 在 signed 解讀為 -1，在 unsigned 解讀為 4294967295。因此相同兩個暫存器與 1 比較時，BLT 與 BLTU 可能得到相反結果。

## B-type 立即數與 PC 選擇

```verilog
// immgen.v, imm_sel = 3'b010
imm = {{19{instr[31]}}, instr[31], instr[7],
       instr[30:25], instr[11:8], 1'b0};

// branch_unit.v
assign branch_target = pc + b_imm;

// core_risb.v
assign next_pc = (branch_taken & is_branch)
               ? branch_target : pc + 32'd4;
```

B-type 位移由 `{instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}` 組成，再符號延伸至 32 bits。最低位固定為 0，位移範圍為 -4096～4094 bytes，單位是 2 bytes；此處的立即數已包含最低位 0，不需再左移。

目標以目前分支的 PC 為基準，不是 `pc + 4`，也不是 `rs1`。例如 PC `0x40` 的 `beq x11,x11,+8` 跳到 `0x48`；PC `0xD8` 的 `bne x14,x0,-4` 跳回 `0xD4`。目前 IMEM 以 `addr[31:2]` 索引，測試目標均為 4-byte 對齊；RTL 尚未提供指令位址未對齊的例外處理。

# Code

- 測試程式

    | PC 範圍 | 內容 | 預期結果 |
    | --- | --- | --- |
    | `0x00`～`0x1C` | ADDI、ADD、SUB、AND、OR、NOP | `x1`～`x6` 為 5、10、15、-5、0、15 |
    | `0x20`～`0x2C` | ADDI、SW、LW、NOP | `x1 = x2 = 42` |
    | `0x30`～`0x3C` | 準備分支運算元 | `x10 = -1`、`x11 = 1`、`x12 = 0x80000000`、`x13 = 0x7FFFFFFF` |
    | `0x40`～`0x9C` | 六種分支各測跳轉與不跳轉 | 跳轉時跳過下一條；不跳轉時執行 NOP |
    | `0xA0`～`0xBC` | BLT/BGE/BLTU/BGEU 的相等邊界 | BLT/BLTU 不跳，BGE/BGEU 跳 |
    | `0xC0`～`0xCC` | Signed 最小值與最大值比較 | BLT、BGE 條件均成立，檢查減法溢位邊界 |
    | `0xD0`～`0xDC` | 計數器與向後 BNE 迴圈 | `x14` 由 3 減至 0，最後 `x30 = 1` |
    | `0xE0` | `beq x0,x0,0` | 停在完成位置 |

    應跳過的位置放置 `addi x31,x31,1`，最後 `x31` 應保持 0，作為錯誤執行的標記。

- Testbench

    `tb_core_risb.v` 維持 R/I → S → B 的分段格式，以 `repeat(...) @(posedge clk)` 執行，再等 `#1` 檢查結果。R/I 等待 8 cycles、S 等待 3 cycles，接著等待 5 cycles 執行 NOP 與分支運算元初始化，到達 PC `0x40`。

    每個前向分支案例在 taken 時執行 1 cycle，not taken 時執行 2 cycles（包含 NOP），再檢查 PC。最後執行 8 cycles 完成計數器初始化、三次迴圈與完成標記，檢查 PC `0xE0`、`x14 = 0`、`x30 = 1`、`x31 = 0`。迴圈中的 BNE 共執行三次：跳轉兩次、不跳轉一次。


# 問題與討論

- 暫無
