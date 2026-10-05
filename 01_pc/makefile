IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TARGET := pc_tb
SRC_LIST := pc.v tb_pc.v

.PHONY: sim wave clean

sim: $(TARGET)
	$(VVP) $(TARGET)

wave: sim
	$(GTKWAVE) pc.vcd

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET) pc.vcd
