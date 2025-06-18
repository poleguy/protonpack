## ##############################################
## Clocks and Timing Constraints
## ##############################################

## Input clocks to the FPGA
#create_clock -name clk_in_p -period 5.000 [get_ports clk_in_p]
#set_input_jitter clk_in_p 0.050


## Set asynchronous clock groups that should not be timed
# https://www.xilinx.com/support/answers/44651.html
# Clock                      Waveform(ns)         Period(ns)      Frequency(MHz)
# -----                      ------------         ----------      --------------
# clk_in_p                   {0.000 2.500}        5.000           200.000         
#   clk_out1_mmcm_102M4      {0.000 4.883}        9.766           102.400         
#     IntClk0                {0.000 0.977}        1.953           512.000         
#     IntClk0Div             {0.000 1.953}        3.906           256.000         
#     IntClk90               {0.488 1.465}        1.953           512.000         
#     IntFbOut               {0.000 4.883}        9.766           102.400         
#     IntMmcm_Bufg_SysClk_3  {0.000 1.953}        3.906           256.000         
#     IntMmcm_Bufg_SysClk_4  {0.000 0.977}        1.953           512.000         
#     IntRefClk              {0.000 1.613}        3.226           310.002         
#   clkfbout_mmcm_102M4      {0.000 12.500}       25.000          40.000          

#         Mmcm_SysClk0        => IntRefClk,   -- out -- 310 MHz for IDELAYCTRL, BUFG
#         
#         Mmcm_SysClk1        => IntClk0,     -- out -- 625 MHz, 00 phase, needs BUFIO
#         Mmcm_SysClk2        => IntClk90,    -- out -- 625 MHz, 90 phase, needs BUFIO 
#         Mmcm_SysClk3        => IntClkDiv,   -- out -- 312.5 MHz, adjustable, BUFG
# -- output doesn't seem to come out if psclk is not clocked
#         Mmcm_SysClk4        => IntClk,      -- out -- 625 MHz, adjustable, BUFG
#         Mmcm_SysClk5        => IntClk0Div,  -- out -- not adjustable 312.5 MHz

# ignore transfers between fixed clock domain and adjustable
## Set the clock groups.  Each clock group is asyncrhnous to the other groups. By default, Xilinx times all clock interactions.
# the main risk here is that paths exist that aren't properly cdc crossed
# check cdc crossing report, or comment out groups and rebuild to double check.
set_clock_groups -name async_clock_groups -asynchronous \
    -group {clk_out1_block_design_clk_wiz_0_0 IntClk0 IntClk0Div IntClk90 IntFbOut clk_256M clkfbout_block_design_clk_wiz_0_0} \     
    -group {IntRefClk} \
    -group {clk_fpga_0} 

#set_false_path -to [get_pins -hier -filter {name =~ cdc_1/signal_meta_reg/D }]
