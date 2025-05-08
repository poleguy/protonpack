set_property PACKAGE_PIN T9 [get_ports T9]
set_property PACKAGE_PIN Y12 [get_ports Y12]

set_property IOSTANDARD LVCMOS18 [get_ports T9]
set_property IOSTANDARD LVCMOS18 [get_ports Y12]


#set_property PACKAGE_PIN U8 [get_ports clk_256M]
#set_property IOSTANDARD LVCMOS18 [get_ports clk_256M]

#set_property PACKAGE_PIN U9 [get_ports reset_mmcm]
#set_property IOSTANDARD LVCMOS18 [get_ports reset_mmcm]


set_property PACKAGE_PIN V8 [get_ports okay_led_out]
set_property IOSTANDARD LVCMOS18 [get_ports okay_led_out]

set_property PACKAGE_PIN W6 [get_ports serial_in_n]

set_property PACKAGE_PIN V6 [get_ports serial_in_p]


# we need external termination!
# 
# [DRC BIVC-1] Bank IO standard Vcc: Conflicting Vcc voltages in bank 13. For example, the following two ports in this bank have conflicting VCCOs:  
# T9 (LVCMOS18, requiring VCCO=1.800) and serial_in_p (LVDS_25, requiring VCCO=2.500)
# 
# [DRC BIVB-1] Bank IO standard Support: Bank 13 has incompatible IO(s) because: The LVDS I/O standard is not supported for banks of type High Range.  Move the following ports or change their properties:  
# serial_in_p
#
# https://adaptivesupport.amd.com/s/article/43989?language=en_US 

set_property IOSTANDARD LVDS_25 [get_ports serial_in_p]
set_property DIFF_TERM FALSE [get_ports serial_in_p]
set_property IOSTANDARD LVDS_25 [get_ports serial_in_n]
set_property DIFF_TERM FALSE [get_ports serial_in_n]



set_property PACKAGE_PIN V11 [get_ports pll_locked]
set_property IOSTANDARD LVCMOS18 [get_ports pll_locked]

set_property PACKAGE_PIN V10 [get_ports rx_dat_aligned]
set_property IOSTANDARD LVCMOS18 [get_ports rx_dat_aligned]

