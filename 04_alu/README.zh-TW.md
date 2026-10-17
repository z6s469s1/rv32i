[English](README.md) | 繁體中文

# ALU

ALU（Arithmetic Logic Unit，算術邏輯單元）負責對兩個 32-bit 輸入進行算術、位元邏輯、比較與位移運算。`alu_op` 選擇操作，`result` 輸出 32-bit 結果，`zero` 表示結果是否為零。

這是組合邏輯模組，沒有 clock 或 reset。輸入改變後，輸出就會跟著更新。

- 電路圖

![ALU](alu.png)

- Port Table

| 訊號 | 方向與寬度 | 功能 |
| --- | --- | --- |
| `a` | 32-bit 輸入 | 第一個運算元 |
| `b` | 32-bit 輸入 | 第二個運算元；最低 5 bits 決定位移量 |
| `alu_op` | 4-bit 輸入 | 選擇十種操作之一 |
| `result` | 32-bit 輸出 | 運算結果 |
| `zero` | 1-bit 輸出 | `result` 為零時輸出 1，否則為 0 |

```verilog
module alu
(
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] alu_op,
    output reg [31:0] result,
    output reg zero
);
```

## 操作表

| alu_op | Operation | Result | Used by |
| :----- | :-------- | :----- | :------ |
| `4'b0000` | ADD — Add | a + b | ADD, ADDI; load/store 位址計算 |
| `4'b0001` | SUB — Subtract | a - b | SUB; BEQ/BNE 比較 |
| `4'b0010` | AND — Bitwise AND | a & b | AND, ANDI |
| `4'b0011` | OR — Bitwise OR | a &#124; b | OR, ORI |
| `4'b0100` | XOR — Bitwise Exclusive OR | a ^ b | XOR, XORI |
| `4'b0101` | SLT — Set Less Than (Signed) | 有號 a < 有號 b ? 1 : 0 | SLT, SLTI |
| `4'b0110` | SLTU — Set Less Than Unsigned | 無號 a < 無號 b ? 1 : 0 | SLTU, SLTIU |
| `4'b0111` | SLL — Shift Left Logical | a << b[4:0] | SLL, SLLI |
| `4'b1000` | SRL — Shift Right Logical | a >> b[4:0] （補 0） | SRL, SRLI |
| `4'b1001` | SRA — Shift Right Arithmetic | 有號 a >>> b[4:0] （補符號位元） | SRA, SRAI |


# Code

- 左右移指令的移動量(shift amount)

    ```verilog
    wire [4:0] shamt = b[4:0];
    ```


- 計算結果

    ```verilog
    always @(*) begin
        case (alu_op)
            // 十種操作，詳見上方表格。
            default: result = 32'd0;
        endcase
        zero = (result == 32'h0000_0000) ? 1'b1 : 1'b0;
    end
    ```



- 測試範例

    | 測試編號 | 操作 | `alu_op` | `a` | `b` | 預期 `result` | `zero` |
    | --- | --- | --- | --- | --- | --- | --- |
    | 1 | ADD | `4'b0000` | `0x00000001` | `0x00000002` | `0x00000003` | 0 |
    | 2 | SUB | `4'b0001` | `0x00000003` | `0x00000002` | `0x00000001` | 0 |
    | 3 | AND | `4'b0010` | `0x00000003` | `0x00000002` | `0x00000002` | 0 |
    | 4 | OR | `4'b0011` | `0x00000003` | `0x00000002` | `0x00000003` | 0 |
    | 5 | XOR | `4'b0100` | `0x00000003` | `0x00000002` | `0x00000001` | 0 |
    | 6 | SLT | `4'b0101` | `0x00000001` | `0x00000002` | `0x00000001` | 0 |
    | 7 | SLTU | `4'b0110` | `0x00000001` | `0x00000002` | `0x00000001` | 0 |
    | 8 | SLL | `4'b0111` | `0x00000001` | `0x00000002` | `0x00000004` | 0 |
    | 9 | SRL | `4'b1000` | `0x00000004` | `0x00000002` | `0x00000001` | 0 |
    | 10 | SRA | `4'b1001` | `0xFFFFFFFC` | `0x00000002` | `0xFFFFFFFF` | 0 |
    | 11 | SUB（檢查 zero flag） | `4'b0001` | `0x00000001` | `0x00000001` | `0x00000000` | 1 |

    以上依照 `tb_alu.v` 的順序列出全部 11 個測試：十種操作各一個，再用相同數值相減檢查 zero flag。

# 問題與討論

- SLT 與 SLTU 有什麼差別？

    當 `a = 0xFFFFFFFF`、`b = 1`，SLT 比較的是 -1 與 1，結果為 1；SLTU 比較的是 4294967295 與 1，結果為 0。兩者都輸出完整的 32-bit 數值 0 或 1。

- SRL 與 SRA 有什麼差別？

    兩者都向右位移，差別是左側空出的位元要補什麼：

    | 操作 | 完整名稱 | 高位補入的值 | 常見用途 |
    | --- | --- | --- | --- |
    | SRL | Shift Right Logical（邏輯右移） | 一律補 0 | 無號數右移、位元處理 |
    | SRA | Shift Right Arithmetic（算術右移） | 補原本的符號位元 `a[31]` | 有號數右移，保留正負號 |

    例如將 `a = 32'hFFFF_FFFC`（以有號數解讀為 -4）右移 2 位：

    ```text
    原值：11111111 11111111 11111111 11111100
    SRL ：00111111 11111111 11111111 11111111 → 0x3FFFFFFF
    SRA ：11111111 11111111 11111111 11111111 → 0xFFFFFFFF（-1）
    ```

    正數的最高位是 0，因此 SRL 與 SRA 的結果相同；負數的最高位是 1，SRA 補 1 以保留負號，SRL 則補 0。

    目前程式的寫法是：

    ```verilog
    // SRL：a 是無號輸入，右移補 0
    result = a >> shamt;
    // SRA：先將 a 視為有號數，再進行算術右移
    result = $signed(a) >>> shamt;
    ```

    `$signed(a)` 很重要：單用 `>>>`，若左側運算元仍是無號數，就不會得到預期的符號延伸。兩種操作都只使用 `b[4:0]` 作為位移量。

    SRA 可視為有號數除以 2 的位移量次方，並向負無限大取整。例如 -3 算術右移 1 位會得到 -2，與有號除法朝零截斷得到的 -1 不同。

- 算術溢位會怎樣？

    輸出只保留最低 32 bits。例如 `0xFFFFFFFF + 1` 會得到零。這個模組沒有提供 carry 或 overflow flag。

- `zero` 代表兩個輸入相等嗎？

    它只代表目前操作的結果為零。使用 SUB 時，結果為零可用來判斷兩個運算元相等；其他操作也可能得到零，所以跳轉控制還需要搭配操作與指令種類判斷。
