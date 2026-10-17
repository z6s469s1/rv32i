# PC

![PC](pc.png)

## Testbench 為什麼需要 `#1`？

`tb_pc.v` 在 clock 上升緣後等待一段時間，再檢查 PC：

```verilog
@(posedge clk);
#1;
check_pc(pc, expected_pc);
```

**這裡的 `#1` 是讓 testbench 等待輸出更新後再檢查。實際電路也會遇到類似的「資料還沒準備好就取樣」問題：若資料未能在取樣 clock 邊緣之前滿足 setup time，就會發生 setup timing violation。**

兩者可以用來類比，但原因不同：TB 這裡是尚未等到模擬器完成 NBA 更新；實際電路則是資料經過暫存器、組合邏輯與連線的傳播延遲後，來不及在取樣期限前穩定。`#1` 解決的是 TB 的觀察時機，實體電路則需要透過時脈週期與資料路徑設計來滿足 setup 要求。

PC 使用 nonblocking assignment（`<=`）更新：

```verilog
always @(posedge clk) begin
    if (rst)
        pc <= 32'h0000_0000;
    else
        pc <= next_pc;
end
```

clock 上升緣發生時，DUT 與 testbench 都會被喚醒。DUT 先計算右側的值，將 `pc` 的更新排到同一模擬時間的 NBA（Nonblocking Assignment）階段；testbench 若立即呼叫 `check_pc`，就會讀到更新前的 `pc`。

```text
clock 上升緣
  → DUT 計算並排程 pc 的更新
  → TB 若立即檢查，會看到舊 pc
  → NBA 階段更新 pc
  → #1 結束後，TB 檢查新 pc
```


## Setup timing violation

![setup_timing](setup_timing.png)

- 參考: https://medium.com/@aiclab.official/clock-to-q-modeling-why-non-blocking-assignments-matter-1b83c9e253b8