IVERILOG ?= iverilog
VVP ?= vvp

TARGET := pc_tb
SRC_LIST := pc.v tb_pc.v

.PHONY: sim clean

sim: $(TARGET)
	$(VVP) $(TARGET)

$(TARGET): $(SRC_LIST) makefile
	$(IVERILOG) -o $@ $(SRC_LIST)

clean:
	rm -f $(TARGET)
