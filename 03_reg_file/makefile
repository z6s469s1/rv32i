IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TARGET := reg_file_tb
SRC_LIST := reg_file.v tb_reg_file.v

.PHONY: sim wave clean

sim: $(TARGET)
	$(VVP) $(TARGET)

wave: sim
	$(GTKWAVE) reg_file.vcd

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET) reg_file.vcd
