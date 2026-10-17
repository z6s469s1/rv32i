IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TARGET := imem_tb
SRC_LIST := pc.v imem.v tb_imem.v

.PHONY: sim wave clean

sim: $(TARGET)
	$(VVP) $(TARGET)

wave: sim
	$(GTKWAVE) imem.vcd

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET) imem.vcd
