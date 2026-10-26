[English](README.md) | 繁體中文

# R/I/S Datapath

本章在 [R/I datapath](../06_ri_datapath/README.zh-TW.md) 上加入資料記憶體存取，重點是 DMEM、Control Unit 新增的 load/store 控制，以及 Write-back MUX。ALU 除了計算算術結果，也負責計算記憶體位址。

這裡沿用資料夾的 R/I/S 名稱；store 使用 S-type，load 則仍是 I-type。PC adder、instruction parser 與 ALUSrc MUX 延用前一章，非 reset 期間 PC 仍固定加 4，尚未支援 branch/jump、LUI 與 AUIPC。

- 電路圖(藍色部分為新增)

![R/I/S Datapath](ris_datapath.png)

## 新增邏輯與資料流

| 新增部分 | 所在位置 | 功能 |
| --- | --- | --- |
| DMEM | `dmem.v`，instance `dmem0` | 同步寫入、非同步讀取，支援 byte／halfword／word |
| Control Unit 擴充 | `control.v` 的 `S`、`L` 分支 | 加入 `mem_write`、`wb_sel`，選擇位址運算與立即數格式 |
| Write-back MUX | `core_ris.v` 的 `assign wb_data` | 選擇 ALU 結果或 DMEM 讀取資料，送回 Register File |

## DMEM（資料記憶體）

DMEM 與存放指令的 IMEM 分開。`DEPTH` 預設為 256，內部實際宣告 `DEPTH × 4` 個 8-bit 元素，共 1024 bytes（1 KiB），byte 位址範圍為 0～1023。`addr` 直接索引 byte，不像 IMEM 使用 `addr[31:2]`。

- Port Table

| 訊號 | 方向與寬度 | 功能 |
| --- | --- | --- |
| `clk` | 1-bit 輸入 | 上升緣執行寫入 |
| `we` | 1-bit 輸入 | 接 `mem_write`，為 1 時允許 store |
| `addr` | 32-bit 輸入 | 接 `alu_result`，為 byte 位址 |
| `wdata` | 32-bit 輸入 | 接 `rdata2`，即 `rs2` 的資料 |
| `funct3` | 3-bit 輸入 | 決定存取寬度與讀取延伸方式 |
| `rdata` | 32-bit 輸出 | 接 `mem_rdata`，為組合邏輯讀取結果 |

```verilog
wire [31:0] mem_rdata;
dmem dmem0 (
    .clk(clk), .we(mem_write),
    .addr(alu_result), .wdata(rdata2),
    .funct3(funct3), .rdata(mem_rdata)
);
```

### 存取寬度與延伸

| `funct3` | Load | 讀取結果 | Store | 寫入資料 |
| --- | --- | --- | --- | --- |
| `000` | LB | 8-bit 符號延伸至 32 bits | SB | `wdata[7:0]` |
| `001` | LH | 16-bit 符號延伸至 32 bits | SH | `wdata[15:0]` |
| `010` | LW | 完整 32 bits | SW | `wdata[31:0]` |
| `100` | LBU | 8-bit 補 0 至 32 bits | — | 不寫入 |
| `101` | LHU | 16-bit 補 0 至 32 bits | — | 不寫入 |

記憶體採 little-endian，最低有效 byte 放在最低位址。讀取沒有 read-enable，隨位址、`funct3` 或相關內容改變而更新；只有 store 在上升緣且 `we = 1` 時修改內容。未列出的 `funct3` 在讀取時輸出 0、寫入時不動作。

DMEM 沒有 reset 或初始化，未寫入位置在模擬中是 `X`。目前沒有位址範圍、對齊檢查或例外處理；多 byte 存取的所有位址都必須位於有效範圍內。

## Control Unit 新增部分

新增 `S = 0100011` 與 `L = 0000011` 兩種 opcode。兩者都令 ALU 執行 ADD，計算 `rs1 + offset`；store 使用 S-type 立即數，load 使用 I-type 立即數。

| 新訊號 | 寬度 | 功能 |
| --- | --- | --- |
| `mem_write` | 1 bit | 控制 DMEM 寫入；store 為 1，其餘為 0 |
| `wb_sel` | 1 bit | 0 選 ALU 結果，1 選記憶體資料 |

| 指令類別 | `opcode` | `reg_write` | `alu_src` | `imm_sel` | `alu_op` | `mem_write` | `wb_sel` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-type ALU | `0110011` | 1 | 0 | — | 依操作選擇 | 0 | 0 |
| I-type ALU | `0010011` | 1 | 1 | `000` | 依操作選擇 | 0 | 0 |
| Store | `0100011` | 0 | 1 | `001` (S) | `0000` | 1 | 0 |
| Load | `0000011` | 1 | 1 | `000` (I) | `0000` | 0 | 1 |

R-type 不使用立即數，表中的 `—` 代表不影響結果，實作預設仍輸出 `000`。Store 不寫回暫存器，因此它的 `wb_sel` 不影響結果。`funct3` 直接送入 DMEM 決定存取寬度，控制單元不需為 SB/SH/SW 分別設定不同的 `alu_op`。

```verilog
// Store (opcode 0100011)
S: begin
    alu_src = 1;
    reg_write = 0;
    imm_sel = 3'b001;
    mem_write = 1;
    wb_sel = 1'b0;
    alu_op = 4'b0000;
end
// Load (opcode 0000011)
L: begin
    alu_src = 1;
    reg_write = 1;
    imm_sel = 3'b000;
    mem_write = 0;
    wb_sel = 1'b1;
    alu_op = 4'b0000;
end
```

## Write-back MUX（寫回選擇器）

```verilog
assign wb_data = wb_sel ? mem_rdata : alu_result;
```

| `wb_sel` | 選擇資料 | 使用時機 |
| --- | --- | --- |
| 0 | `alu_result` | R/I ALU 指令的計算結果 |
| 1 | `mem_rdata` | Load 從 DMEM 讀出的資料 |

`wb_sel` 只決定資料來源，是否寫入仍由 `reg_write` 決定。Store 使用 ALU 結果當位址、`rdata2` 當寫入資料，並設 `reg_write = 0`，所以不會將位址寫回暫存器。ALUSrc MUX 選擇的是 ALU 的輸入，Write-back MUX 選擇的是送回 Register File 的輸出。

# Code

- DMEM 的 SW／LW 資料排列

    ```verilog
    reg [7:0] mem [0:(DEPTH*4)-1];

    // SW, inside always @(posedge clk), when we and funct3 == 3'b010
    mem[addr]   <= wdata[7:0];
    mem[addr+1] <= wdata[15:8];
    mem[addr+2] <= wdata[23:16];
    mem[addr+3] <= wdata[31:24];

    // LW, inside always @(*), when funct3 == 3'b010
    rdata = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};
    ```

- Store／Load 執行流程

    `sw x1, 0(x0)`：以 S-type 立即數 0 與 `x0` 相加，得到位址 0。DMEM 在上升緣將 `x1` 的資料寫入位址 0～3，Register File 不寫入。

    `lw x2, 0(x0)`：以 I-type 立即數 0 計算相同位址，DMEM 以組合邏輯讀出資料。Write-back MUX 選 `mem_rdata`，在下一個上升緣寫入 `x2`。因此在此單週期模型中，緊接於 SW 後的 LW 可讀到剛寫入的資料。

- 測試範例

    目前 `program.hex` 先執行八條 R/I 指令（含兩條 NOP），再執行以下四條。`tb_core_ris.v` 在八個上升緣後等待 1 ns，檢查 `x1`～`x6` 為 5、10、15、-5、0、15；再等待三個上升緣與 1 ns，檢查 `x1`、`x2` 都是 42。共八項暫存器結果檢查，尚未測試 byte／halfword 存取或有號／無號 load 差異。

    | PC | 機器碼 | 指令 | 預期結果 |
    | --- | --- | --- | --- |
    | 0x20 | `02A00093` | `addi x1, x0, 42` | `x1 = 42` |
    | 0x24 | `00102023` | `sw x1, 0(x0)` | `mem[0:3]` 依序為 `2A 00 00 00` |
    | 0x28 | `00002103` | `lw x2, 0(x0)` | `x2 = 42` |
    | 0x2C | `00000013` | `nop` | 不改變一般暫存器 |

# 問題與討論

- 暫無
