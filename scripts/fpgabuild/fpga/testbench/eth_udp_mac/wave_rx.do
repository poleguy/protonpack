onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_rx/clk
add wave -noupdate /tb_rx/rst
add wave -noupdate /tb_rx/tdata
add wave -noupdate /tb_rx/tlast
add wave -noupdate /tb_rx/tready
add wave -noupdate /tb_rx/tvalid
add wave -noupdate /tb_rx/rxd
add wave -noupdate /tb_rx/rxd_en
add wave -noupdate /tb_rx/eth_udp_mac_rx/mac_gmii_en
add wave -noupdate /tb_rx/eth_udp_mac_rx/mac_dest
add wave -noupdate /tb_rx/eth_udp_mac_rx/mac_src
add wave -noupdate /tb_rx/eth_udp_mac_rx/ip_src
add wave -noupdate /tb_rx/eth_udp_mac_rx/ip_dest
add wave -noupdate /tb_rx/eth_udp_mac_rx/udp_src
add wave -noupdate /tb_rx/eth_udp_mac_rx/udp_dest
add wave -noupdate /tb_rx/eth_udp_mac_rx/udp_len
add wave -noupdate -radix unsigned /tb_rx/eth_udp_mac_rx/udp_len
add wave -noupdate -radix unsigned /tb_rx/eth_udp_mac_rx/pkt_udp_btt
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/clk
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/crc_en
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/crc_in
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/crc_out
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/fcs
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/rst
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/txd
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/txd_en
add wave -noupdate -group fcs_gen /tb_rx/eth_udp_mac_rx/eth_fcs_gen/txd_en_cnt
add wave -noupdate /tb_rx/eth_udp_mac_rx/tdata_int
add wave -noupdate /tb_rx/eth_udp_mac_rx/state
add wave -noupdate -radix unsigned /tb_rx/eth_udp_mac_rx/rxd_cnt
add wave -noupdate -radix unsigned /tb_rx/eth_udp_mac_rx/pload_cnt
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
