[English](README.md) | 繁體中文

# 立即數產生器（ImmGen）

立即數產生器從 RV32I 指令擷取並重組 32-bit 立即數，由控制單元透過 `imm_sel` 選擇格式。這是組合邏輯，沒有 clock 或 reset；任一輸入改變時，`imm` 就會更新。

- 電路圖

![ImmGen](immgen.png)

- Port Table

| 訊號 | 方向與寬度 | 功能 |
| --- | --- | --- |
| `instr` | 32-bit 輸入 | 完整指令字 |
| `imm_sel` | 3-bit 輸入 | 控制單元選擇的立即數格式 |
| `imm` | 32-bit 輸出 | 重組後的立即數或偏移量 |

```verilog
module immgen (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_sel,
    output reg  [31:0] imm
);
```

- 格式表

| `imm_sel` | Type | 符號延伸前的立即數位元 | 指令範例 | 數值範圍／配置 |
| --- | --- | --- | --- | --- |
| `3'b000` | I (Immediate) | `instr[31:20]` | ADDI, LW, JALR | -2048～2047 |
| `3'b001` | S (Store) | `{instr[31:25], instr[11:7]}` | SB, SH, SW | -2048～2047 |
| `3'b010` | B (Branch) | `{instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}` | BEQ, BNE, BLT | -4096～4094 bytes，間隔 2 bytes |
| `3'b011` | U (Upper Immediate) | `{instr[31:12], 12'b0}` | LUI, AUIPC | 高 20 bits 來自指令，低 12 bits 補 0 |
| `3'b100` | J (Jump) | `{instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}` | JAL | -1,048,576～1,048,574 bytes，間隔 2 bytes |

I/S/B/J 使用 `instr[31]` 作為符號位元，延伸成 32 bits。U-type 在低位補上 12 個 0，直接形成完整的 32-bit 值。選擇碼 `101`、`110`、`111` 輸出 0。R-type 沒有立即數，因此不需要專用選擇碼。

B/J 輸出已包含隱含的最低位 0，不需再左移。CPU 將偏移量加到目前指令的 PC；load/store 與 JALR 則將 I/S 立即數加到 `rs1`，JALR 還要清除目標位址的 bit 0。ImmGen 只產生立即數，不計算位址或檢查目標對齊。

# Code

- 重組立即數

    ```verilog
    always @(*) begin
        case (imm_sel)
            3'b000: imm = {{20{instr[31]}}, instr[31:20]};           // I
            3'b001: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S
            3'b010: imm = {{19{instr[31]}}, instr[31], instr[7],     // B
                           instr[30:25], instr[11:8], 1'b0};
            3'b011: imm = {instr[31:12], 12'b0};                     // U
            3'b100: imm = {{11{instr[31]}}, instr[31], instr[19:12], // J
                           instr[20], instr[30:21], 1'b0};
            default: imm = 32'd0;
        endcase
    end
    ```

    串接運算（`{...}`）重排指令欄位；重複運算（例如 `{20{instr[31]}}`）用符號位元填滿高位。`default` 定義未使用選擇碼的輸出，避免產生 latch。

- 測試範例

    `tb_immgen.v` 包含 16 個自動檢查案例。每個案例設定輸入後等待 1 ns，再使用 `!==` 比對結果，因此未知值也會判定為失敗。

    | 測試範圍 | 案例 |
    | --- | --- |
    | I | 0、10、-2048：零、正數與符號延伸 |
    | S | 12、-2048：分段立即數與符號延伸 |
    | B | 8、2048、-4096：最低位補 0、bit 11 重排與符號延伸 |
    | U | `0x12345000`、`0x80000000`：低 12 bits 清零與最高位保留 |
    | J | 16、2048、-1,048,576：最低位補 0、bit 11 重排與符號延伸 |
    | 未使用選擇碼 | `101`、`110`、`111` 搭配全 1 指令時輸出 0 |

    預期結果使用固定常數。指令中與立即數無關的欄位設為 1，確認這些欄位不影響輸出。失敗時顯示輸入、實際值與預期值，並以 `$fatal(1, ...)` 讓 `make sim` 回報失敗；全部通過時顯示 `All 16 tests passed!`。

# 問題與討論

- 為什麼 `imm_sel` 由控制單元提供？

    此模組不解碼 `opcode`，也不檢查指令是否合法。控制單元必須選擇正確的立即數格式。

- 為什麼 B/J 的立即數分成多段？

    指令編碼將偏移量位元分散在不同位置。ImmGen 將它們還原成數值順序，並補上隱含的最低位 0。可對照 [ISA 格式比較表](../00_isa/README.zh-TW.md)。

- 立即數位移指令會使用整個 I-type 輸出當位移量嗎？

    不會。RV32I 的立即數位移只使用低 5 bits 作為 `shamt`，指令的高位用來區分操作，必須由 ALU／控制邏輯配合處理。
