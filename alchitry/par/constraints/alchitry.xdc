set_property PACKAGE_PIN W19 [get_ports {clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {clk}]
# clk => 100000000Hz
# don't use name clk_0 because it collides with clk_wiz naming
#create_clock -period 10.0 -name clk_0 -waveform {0.000 5.0} [get_ports clk]
#set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks clk_0]

set_property PACKAGE_PIN N15 [get_ports {rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {rst_n}]

set_property PACKAGE_PIN P19 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN P20 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN T21 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN R19 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN V22 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

set_property PACKAGE_PIN U21 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]

set_property PACKAGE_PIN T20 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]

set_property PACKAGE_PIN W20 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

set_property PACKAGE_PIN AA20 [get_ports {usb_rx}]
set_property IOSTANDARD LVCMOS33 [get_ports {usb_rx}]

set_property PACKAGE_PIN AA21 [get_ports {usb_tx}]
set_property IOSTANDARD LVCMOS33 [get_ports {usb_tx}]

set_property PACKAGE_PIN H4 [get_ports {ft_clk}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_clk}]
# ft_clk => 100000000Hz
create_clock -period 10.0 -name ft_clk_12 -waveform {0.000 5.0} [get_ports ft_clk]
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks ft_clk_12]

set_property PACKAGE_PIN AB22 [get_ports {ft_wakeup}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_wakeup}]

set_property PACKAGE_PIN AB21 [get_ports {ft_reset}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_reset}]

set_property PACKAGE_PIN N2 [get_ports {ft_rxf}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_rxf}]

set_property PACKAGE_PIN P2 [get_ports {ft_txe}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_txe}]

set_property PACKAGE_PIN AB18 [get_ports {ft_oe}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_oe}]

set_property PACKAGE_PIN AA18 [get_ports {ft_rd}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_rd}]

set_property PACKAGE_PIN E3 [get_ports {ft_wr}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_wr}]

set_property PACKAGE_PIN M2 [get_ports {ft_be[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_be[0]}]

set_property PACKAGE_PIN F3 [get_ports {ft_be[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_be[1]}]

set_property PACKAGE_PIN G4 [get_ports {ft_data[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[0]}]

set_property PACKAGE_PIN P5 [get_ports {ft_data[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[1]}]

set_property PACKAGE_PIN P4 [get_ports {ft_data[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[2]}]

set_property PACKAGE_PIN P6 [get_ports {ft_data[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[3]}]

set_property PACKAGE_PIN N5 [get_ports {ft_data[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[4]}]

set_property PACKAGE_PIN M6 [get_ports {ft_data[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[5]}]

set_property PACKAGE_PIN M5 [get_ports {ft_data[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[6]}]

set_property PACKAGE_PIN L5 [get_ports {ft_data[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[7]}]

set_property PACKAGE_PIN L4 [get_ports {ft_data[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[8]}]

set_property PACKAGE_PIN K6 [get_ports {ft_data[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[9]}]

set_property PACKAGE_PIN J6 [get_ports {ft_data[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[10]}]

set_property PACKAGE_PIN E2 [get_ports {ft_data[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[11]}]

set_property PACKAGE_PIN D2 [get_ports {ft_data[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[12]}]

set_property PACKAGE_PIN M3 [get_ports {ft_data[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[13]}]

set_property PACKAGE_PIN M1 [get_ports {ft_data[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[14]}]

set_property PACKAGE_PIN L1 [get_ports {ft_data[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ft_data[15]}]

# new pins for serial telemetry stuff

#set_property PACKAGE_PIN  [get_ports {GTREFCLK0P_I[0]}]
#set_property PACKAGE_PIN  [get_ports {GTREFCLK0N_I[0]}]

# GTP: no I/O Std needed:
# GTP was allowed to route and then pins were grabbed from post_route.dcp

# Route back in 128MHz from REC_CLOCK_P (looped back on board)
set_property PACKAGE_PIN F6 [get_ports {GTREFCLK1P_I[0]}]
#set_property PACKAGE_PIN AB11 [get_ports {GTREFCLK1N_I[0]}]
set_property PACKAGE_PIN D9 [get_ports {RXP_I}]
#set_property PACKAGE_PIN AF11 [get_ports {RXN_I}]

# Route out 128MHz to drive GTREFCLK1P_I[0]
set_property PACKAGE_PIN  U6      [get_ports {REC_CLOCK_P}]
set_property IOSTANDARD LVCMOS33 [get_ports {REC_CLOCK_P}]
set_property PACKAGE_PIN  V5      [get_ports {REC_CLOCK_N}]
set_property IOSTANDARD LVCMOS33      [get_ports {REC_CLOCK_N}]

#set_property PACKAGE_PIN   W15     [get_ports {USER_SMA_CLK_P}]
#set_property IOSTANDARD LVDS_25      [get_ports {USER_SMA_CLK_P}]
#set_property PACKAGE_PIN   H23     [get_ports {USER_SMA_CLK_N}]
#set_property IOSTANDARD LVDS_25      [get_ports {USER_SMA_CLK_N}]

#V7 34_L19_P 30
#W7 34_L19_N 28
// labeled to match top side pin numbers and Br Breakout board silk screen
set_property PACKAGE_PIN V7 [get_ports {BOT_B30}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_B30}]
set_property PACKAGE_PIN W7 [get_ports {BOT_B28}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_B28}]

# toggle pin inputs
set_property PACKAGE_PIN Y2 [get_ports {BOT_B3}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_B3}]
set_property PULLTYPE PULLUP [get_ports {BOT_B3}]
set_property PACKAGE_PIN W2 [get_ports {BOT_B5}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_B5}]
set_property PULLTYPE PULLUP [get_ports {BOT_B5}]

# led outputs mimicked on connector C bottom side
set_property PACKAGE_PIN U1 [get_ports {BOT_C_L[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[0]}]
set_property PACKAGE_PIN T1 [get_ports {BOT_C_L[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[1]}]
set_property PACKAGE_PIN R2 [get_ports {BOT_C_L[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[2]}]
set_property PACKAGE_PIN R3 [get_ports {BOT_C_L[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[3]}]
set_property PACKAGE_PIN W5 [get_ports {BOT_C_L[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[4]}]
set_property PACKAGE_PIN W6 [get_ports {BOT_C_L[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[5]}]
set_property PACKAGE_PIN V3 [get_ports {BOT_C_L[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[6]}]
set_property PACKAGE_PIN U3 [get_ports {BOT_C_L[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {BOT_C_L[7]}]


## Set clock groups for timing analysis.
## This tells Vivado to time paths internal to a clock group
## but do not time paths that go between clock groups.
## Paths between clock groups are CDC and should be handled by
## rtl cdc approaches and validated via report_cdc flow.
##
## All the mmcm outputs for a given instantiation are sync
## to one another and can be treated as such.
##
set_clock_groups -name async_groups -asynchronous \
    -group [get_clocks {clkfbout_clk_wiz_100M clk_out1_clk_wiz_100M}] \
    -group [get_clocks {clkfbout clkout0 clkout1}] \
    -group [get_clocks {clkfbout_1 clkout0_1 clkout1_1}] \
    -group [get_clocks ft_clk_12] \
    -group [get_clocks {clkfbout_mmcm_128M_256M clk_out2_mmcm_128M_256M}]
