This file is currently not set up correctly or used, because we use alchitry to program the board.
I'm leaving it as a clue if we end up spinning our own board.
## TCL Script for programming the flash part on the .... board

## Call tcl script using vivado -source program_flash.tcl

set FLASH_IMAGE "output/alchitry_top_working.bin"

set FLASH_PART mx25u6435f-spi-x1_x2_x4
# oak park:
#set HW_TARGET "*/xilinx_tcf/Xilinx/000015de5c0f01"
# haydn:
#set HW_TARGET "*/xilinx_tcf/Xilinx/00001d9a9dad01"
#set HW_TARGET "*/xilinx_tcf/Xilinx/00001cda031501"
# generic... hopefully it finds the right one.
set HW_TARGET "*/xilinx_tcf/Xilinx/*"

open_hw
connect_hw_server
# if only one target is connected, you can use this:
# this can also be used to list the possible targets (via the error message)
#set HW_TARGET "*/xilinx_tcf/Xilinx/*"
# otherwise, specify exactly:
# haydn.shure.com hardware:
# new dongle, node 1:
current_hw_target [get_hw_targets $HW_TARGET]

open_hw_target
current_hw_device [get_hw_devices xc7s25_0]
refresh_hw_device [lindex [get_hw_devices xc7s25_0] 0]
create_hw_cfgmem -hw_device [lindex [get_hw_devices xc7s25_0] 0] [lindex [get_cfgmem_parts $FLASH_PART] 0]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
refresh_hw_device [lindex [get_hw_devices xc7s25_0] 0]
set_property PROGRAM.ADDRESS_RANGE  {use_file} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.FILES [list $FLASH_IMAGE ] [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.PRM_FILE {} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]

startgroup 

# this if needs a comment. what does it do?
if {![string equal [get_property PROGRAM.HW_CFGMEM_TYPE  [lindex [get_hw_devices xc7s25_0] 0]] [get_property MEM_TYPE [get_property CFGMEM_PART [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]]]] }  { create_hw_bitstream -hw_device [lindex [get_hw_devices xc7s25_0] 0] [get_property PROGRAM.HW_CFGMEM_BITFILE [ lindex [get_hw_devices xc7s25_0] 0]]; program_hw_devices [lindex [get_hw_devices xc7s25_0] 0]; }; 
# if this command fails with "Program File cannot be empty" or "ERROR: [Labtools 27-3347] Flash Programming Unsuccessful: Program File cannot be empty" check the spelling/existance of $FLASH_IMAGE
program_hw_cfgmem -hw_cfgmem [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7s25_0] 0]]
endgroup

close_hw

# don't run this exit if you want to run this interactively
exit




