IVERILOG ?= iverilog
VVP ?= vvp
GTKWAVE ?= gtkwave

TARGET := tb_core_ris
SRC_LIST := core_ris.v tb_core_ris.v alu.v control.v immgen.v reg_file.v imem.v pc.v dmem.v

.PHONY: sim wave clean

sim: $(TARGET)
	$(VVP) $(TARGET)

wave: sim
	$(GTKWAVE) tb_core_ris.vcd

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET) tb_core_ris.vcd
