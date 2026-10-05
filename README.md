# RV32I

## PC Simulation and Waveforms

Install the required tools on Ubuntu:

```sh
sudo apt-get update
sudo apt-get install -y iverilog gtkwave
```

Run the simulation and generate `pc.vcd`:

```sh
cd code/rv32i/01_pc
make sim
```

Open the waveform viewer in an environment with a graphical desktop:

```sh
make wave
```

## Reference
- https://ecrionix.org/riscv-from-scratch/
