IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TARGET := immgen_tb
SRC_LIST := immgen.v tb_immgen.v

.PHONY: sim wave clean

sim: $(TARGET)
	$(VVP) $(TARGET)

wave: sim
	$(GTKWAVE) immgen.vcd

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -g2012 -s tb_immgen -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET) immgen.vcd
