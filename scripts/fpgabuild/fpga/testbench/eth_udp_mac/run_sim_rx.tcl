vcom -2008 \
../rtl/eth_crc32_8in.vhd \
../rtl/eth_fcs_gen.vhd \
eth_fcs_calc_pkg.vhd \
eth_test_pkg.vhd \
../rtl/eth_udp_mac_rx.vhd \
../rtl/eth_reg_handler.vhd \
tb_rx.vhd

vsim tb_rx; log -r *; do wave_rx.do; 
#set StdArithNoWarnings 1
#set NumericStdNoWarnings 1
run -a
