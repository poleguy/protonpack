onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_tx/eth_app_test/state
add wave -noupdate /tb_tx/tdata
add wave -noupdate /tb_tx/tlast
add wave -noupdate /tb_tx/tready
add wave -noupdate /tb_tx/tvalid
add wave -noupdate /tb_tx/txd
add wave -noupdate /tb_tx/txd_en
add wave -noupdate -radix unsigned /tb_tx/eth_udp_mac_tx/udp_len
add wave -noupdate -radix unsigned /tb_tx/eth_udp_mac_tx/ip_len
add wave -noupdate -radix unsigned /tb_tx/eth_udp_mac_tx/pkt_udp_btt
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/clk
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/crc_en
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/crc_in
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/crc_out
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/fcs
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/rst
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/txd
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/txd_en
add wave -noupdate -group fcs_gen /tb_tx/eth_udp_mac_tx/eth_fcs_gen/txd_en_cnt
add wave -noupdate /tb_tx/eth_udp_mac_tx/txd_fcs
add wave -noupdate /tb_tx/eth_udp_mac_tx/state
add wave -noupdate -radix hexadecimal /tb_tx/eth_udp_mac_tx/txd_cnt
add wave -noupdate /tb_tx/eth_udp_mac_tx/txd_sel
add wave -noupdate /tb_tx/eth_udp_mac_tx/app_rdy_hdr
add wave -noupdate /tb_tx/eth_udp_mac_tx/app_rdy_pload
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1068 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {995 ns} {1141 ns}
