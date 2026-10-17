[English](README.md) | 繁體中文

# RV32I

## PC 模擬與波形

在 Ubuntu 安裝所需工具：

```sh
sudo apt-get update
sudo apt-get install -y iverilog gtkwave
```

執行模擬並產生 VCD 波形檔：

```sh
cd code/rv32i/01_pc
make sim
```

在具有圖形桌面的環境中開啟波形檢視器：

```sh
make wave
```

## 參考資料

- https://ecrionix.org/riscv-from-scratch/
