# Makefile

# defaults
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

#VERILOG_SOURCES += $(PWD)/my_design.sv
# use VHDL_SOURCES for VHDL files

# COCOTB_TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
#COCOTB_TOPLEVEL = my_design

# COCOTB_TEST_MODULES is the basename of the Python test file(s)
COCOTB_TEST_MODULES = test_verilator
EXTRA_ARGS = --timing -Wno-PINCONNECTEMPTY -Wno-PROCASSINIT -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC --trace --trace-fst
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim
