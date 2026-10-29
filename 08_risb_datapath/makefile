IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TARGET := tb_core_risb
SRC_LIST := core_risb.v tb_core_risb.v alu.v control.v immgen.v reg_file.v imem.v pc.v dmem.v branch_unit.v

.PHONY: sim wave clean

sim: $(TARGET)
	$(VVP) $(TARGET)

wave: sim
	$(GTKWAVE) tb_core_risb.vcd

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET) tb_core_risb.vcd
