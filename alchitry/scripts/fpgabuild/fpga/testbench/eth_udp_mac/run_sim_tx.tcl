vcom -2008 \
../rtl/eth_crc32_8in.vhd \
../rtl/eth_fcs_gen.vhd \
eth_fcs_calc_pkg.vhd \
eth_test_pkg.vhd \
../rtl/eth_udp_mac_tx.vhd \
../rtl/eth_app_test_ex.vhd \
tb_tx.vhd

vsim tb_tx; log -r *; do wave_tx.do;
#set StdArithNoWarnings 1
#set NumericStdNoWarnings 1
run -a
