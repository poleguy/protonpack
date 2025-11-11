create_waiver -type CDC -from [get_clocks clk_out1_clk_wiz_100M] -to [list [get_pins -hierarchical -filter {NAME =~ */gt0_gt_serial_telem_rx_i/gtpe2_i/RXOUTCLK}] -description "Expected asynchronous crossing for GT RX clock path"

#############################################################################################
### Ignore all paths to debug ILAs.... ila_core_inst should cover all ILAs
#############################################################################################

# create_waiver -type CDC -id CDC-1 -to [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-7 -to [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-10 -to [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-11 -to [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-13 -to [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"

# create_waiver -type CDC -id CDC-1 -from [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-7 -from [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-10 -from [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-11 -from [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"
# create_waiver -type CDC -id CDC-13 -from [list [get_pins -hierarchical -filter {NAME =~ */ila_core_inst/*}]] -description "CDCs in ILA OK"


#############################################################################################
### Ignore all paths to all debug vio's....
### At risk of controlling hitting controls asynchronously
### But really these controls should move to register interfaces and be synchronized
#############################################################################################

#create_waiver -type CDC -id CDC-1 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-7 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-10 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-11 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-13 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#
#create_waiver -type CDC -id CDC-1 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-7 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-10 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-11 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-13 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_OUT_ALL_INST/*}]] -description "CDCs in ILA OK"
#
#
#create_waiver -type CDC -id CDC-1 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-7 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-10 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-11 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-13 -to [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#
#create_waiver -type CDC -id CDC-1 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-7 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-10 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-11 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"
#create_waiver -type CDC -id CDC-13 -from [list [get_pins -hierarchical -filter {NAME =~ */PROBE_IN_INST/*}]] -description "CDCs in ILA OK"


