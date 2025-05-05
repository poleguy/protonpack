#
#--------------------------------------------------------------------------------------------
#- Location Constraints
#--------------------------------------------------------------------------------------------
# View also location constraints for BUFIO, BUFR, IDELAYCTRL, MCM in the HDL files.
# These two location constraints are for the MMCM clock adjusting FIFO's
#set_property LOC ILOGIC_X0Y23 [get_cells -hier -filter {name =~ */MmcmAlignIo_I_Isrdse2_Clk}]
#set_property LOC OLOGIC_X0Y23 [get_cells -hier -filter {name =~ */MmcmAlignIo_I_Osrdse2_Clk}]

# this must match setting of BUFIO in hdl

set_property LOC ILOGIC_X0Y11 [get_cells -hier -filter {name =~ */MmcmAlignIo_I_Isrdse2_Clk}]
set_property LOC OLOGIC_X0Y11 [get_cells -hier -filter {name =~ */MmcmAlignIo_I_Osrdse2_Clk}]
#set_property LOC ILOGIC_X0Y124 [get_cells -hier -filter {name =~ */MmcmAlignIo_I_Isrdse2_Clk}]
#set_property LOC OLOGIC_X0Y124 [get_cells -hier -filter {name =~ */MmcmAlignIo_I_Osrdse2_Clk}]


#set_property LOC OLOGIC_X0Y23 [get_cells -hier -filter {name =~ */Receiver_0/Receiver_I_Bufio_Clk0}]

# The IO pins (IOB) associated with these ISERDES/OSERDES are prohibited in the used
# IO-Bank.
#
# https://www.xilinx.com/support/answers/67224.html
# see page 11: get_nets
# https://www.xilinx.com/support/documentation/sw_manuals/xilinx2019_2/ug912-vivado-properties.pdf
#NET "Clk_p_pin" CLOCK_DEDICATED_ROUTE = BACKBONE;
#PIN "*/Receiver_I_RxGenClockMod/RxGenClockMod_I_Mmcm_Adv.CLKIN1" CLOCK_DEDICATED_ROUTE = BACKBONE;
#set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_pins -hier -filter {name =~ */Receiver_I_RxGenClockMod/RxGenClockMod_I_Mmcm_Adv/CLKIN1}]
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_102M4_IBUF]
#
#INST "*/Gen_1[1].Receiver_I_Dru" AREA_GROUP = "Gen_1[1].Rcvr_I_Dru";
#AREA_GROUP "Gen_1[1].Rcvr_I_Dru" RANGE=SLICE_X0Y25:SLICE_X9Y26;
#
#INST "*/Gen_1[2].Receiver_I_Dru" AREA_GROUP = "Gen_1[2].Rcvr_I_Dru";
#AREA_GROUP "Gen_1[2].Rcvr_I_Dru" RANGE=SLICE_X0Y27:SLICE_X9Y28;
#
#INST "*/Receiver_I_RxGenClockMod/RxGenClockMod_I_AppsRstEna" AREA_GROUP = "RxGnClckMd_I_ApsRstEn";
#AREA_GROUP "RxGnClckMd_I_ApsRstEn" RANGE=SLICE_X6Y23:SLICE_X9Y24;
#INST "*/Receiver_I_MmcmAlign" AREA_GROUP = "Rcvr_I_MmcmAlgn";
#AREA_GROUP "Rcvr_I_MmcmAlgn" RANGE=SLICE_X0Y23:SLICE_X5Y24;
#
# For convenience reasons (testing) the "unnecessary" logic of the design has been fixed (LOCked)
# in a SLICE area too.
#INST "*/Receiver_I_RxGenClockMod/RxGenClockMod_I_LifeIndicator" AREA_GROUP = "RxGnClckMd_I_LfIndctr";
#AREA_GROUP "RxGnClckMd_I_LfIndctr" RANGE=SLICE_X12Y15:SLICE_X13Y18;
#INST "*/Receiver_I_RxGenClockMod/RxGenClockMod_I_TimeTickCnt" AREA_GROUP = "RxGnClckMd_I_TmTckCnt";
#AREA_GROUP "RxGnClckMd_I_TmTckCnt" RANGE=SLICE_X14Y15:SLICE_X15Y18;



# User Generated physical constraints

# based on reference design
# create_pblock {pblock_Gn_1[1].Rcvr_I_Dr}
# add_cells_to_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] [get_cells -quiet [list {check_telemetry_1/Receiver_0/Gen_1[1].Receiver_I_Dru}]]
# resize_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] -add {SLICE_X0Y25:SLICE_X9Y26}
# create_pblock pblock_RxGnClckMd_I_ApsRstEn
# add_cells_to_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] [get_cells -quiet [list check_telemetry_1/Receiver_0/Receiver_I_RxGenClockMod/RxGenClockMod_I_AppsRstEna]]
# resize_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] -add {SLICE_X6Y23:SLICE_X9Y24}
# create_pblock pblock_Receiver_I_MmcmAlign
# add_cells_to_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] [get_cells -quiet [list check_telemetry_1/Receiver_0/Receiver_I_MmcmAlign]]
# resize_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] -add {SLICE_X0Y23:SLICE_X5Y24}

# # shifted down in hopes of improving timing
# create_pblock {pblock_Gn_1[1].Rcvr_I_Dr}
# add_cells_to_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] [get_cells -quiet [list {check_telemetry_1/Receiver_0/Gen_1[1].Receiver_I_Dru}]]
# resize_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] -add {SLICE_X0Y77:SLICE_X9Y78}
# create_pblock pblock_RxGnClckMd_I_ApsRstEn
# add_cells_to_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] [get_cells -quiet [list check_telemetry_1/Receiver_0/Receiver_I_RxGenClockMod/RxGenClockMod_I_AppsRstEna]]
# resize_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] -add {SLICE_X6Y75:SLICE_X9Y76}
# create_pblock pblock_Receiver_I_MmcmAlign
# add_cells_to_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] [get_cells -quiet [list check_telemetry_1/Receiver_0/Receiver_I_MmcmAlign]]
# resize_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] -add {SLICE_X0Y75:SLICE_X5Y76}


# shifted to center of X0Y1, Bigger DRU slice to meet timing.
# Dru misses timing easily, so straddle it across the middle to try to get clock delay down
create_pblock {pblock_Gn_1[1].Rcvr_I_Dr}
add_cells_to_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] [get_cells -hier -filter {name =~ *block_design_i/telem_0/inst/check_telemetry_1/Receiver_0/Gen_1[1].Receiver_I_Dru}]
resize_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] -add {SLICE_X0Y14:SLICE_X9Y16}
create_pblock pblock_RxGnClckMd_I_ApsRstEn
add_cells_to_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] [get_cells -hier -filter {name =~ *check_telemetry_1/Receiver_0/Receiver_I_RxGenClockMod/RxGenClockMod_I_AppsRstEna}]
resize_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] -add {SLICE_X6Y14:SLICE_X9Y15}
create_pblock pblock_Receiver_I_MmcmAlign
add_cells_to_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] [get_cells -hier -filter {name =~ *check_telemetry_1/Receiver_0/Receiver_I_MmcmAlign}]
resize_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] -add {SLICE_X0Y14:SLICE_X5Y15}


# shifted to center of X0Y2, Bigger DRU slice to meet timing.
# Dru misses timing easily, so straddle it across the middle to try to get clock delay down
# create_pblock {pblock_Gn_1[1].Rcvr_I_Dr}
# add_cells_to_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] [get_cells -quiet [list {check_telemetry_1/Receiver_0/Gen_1[1].Receiver_I_Dru}]]
# resize_pblock [get_pblocks {pblock_Gn_1[1].Rcvr_I_Dr}] -add {SLICE_X0Y124:SLICE_X9Y126}
# create_pblock pblock_RxGnClckMd_I_ApsRstEn
# add_cells_to_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] [get_cells -quiet [list check_telemetry_1/Receiver_0/Receiver_I_RxGenClockMod/RxGenClockMod_I_AppsRstEna]]
# resize_pblock [get_pblocks pblock_RxGnClckMd_I_ApsRstEn] -add {SLICE_X6Y122:SLICE_X9Y123}
# create_pblock pblock_Receiver_I_MmcmAlign
# add_cells_to_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] [get_cells -quiet [list check_telemetry_1/Receiver_0/Receiver_I_MmcmAlign]]
# resize_pblock [get_pblocks pblock_Receiver_I_MmcmAlign] -add {SLICE_X0Y122:SLICE_X5Y123}

# try forcing stuff to meet timing
#set_property LOC MMCME2_ADV_X0Y0 [get_cells mmcm_102M4_1/mmcm_adv_inst]



#--------------------------------------------------------------------------------------------
#- End
#--------------------------------------------------------------------------------------------
#

