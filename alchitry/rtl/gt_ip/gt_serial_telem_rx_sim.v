//fake for sim

`default_nettype wire

`timescale 1ns / 1ps
`define DLY #1

//***************************** Entity Declaration ****************************
module gt_serial_telem_rx 
(
input           soft_reset_tx_in,
input           soft_reset_rx_in,
input           dont_reset_on_data_error_in,
    input  q0_clk1_gtrefclk_pad_n_in,
    input  q0_clk1_gtrefclk_pad_p_in,
output          gt0_tx_mmcm_lock_out,
output          gt0_rx_mmcm_lock_out,
output          gt0_tx_fsm_reset_done_out,
output          gt0_rx_fsm_reset_done_out,
input           gt0_data_valid_in,
 
    output   gt0_txusrclk_out,
    output   gt0_txusrclk2_out,
    output   gt0_rxusrclk_out,
    output   gt0_rxusrclk2_out,

    //_________________________________________________________________________
    //GT0  (X0Y0)
    //____________________________CHANNEL PORTS________________________________
    //-------------------------- Channel - DRP Ports  --------------------------
    input   [8:0]   gt0_drpaddr_in,
    input   [15:0]  gt0_drpdi_in,
    output  [15:0]  gt0_drpdo_out,
    input           gt0_drpen_in,
    output          gt0_drprdy_out,
    input           gt0_drpwe_in,
    //------------------- RX Initialization and Reset Ports --------------------
    input           gt0_eyescanreset_in,
    input           gt0_rxuserrdy_in,
    //------------------------ RX Margin Analysis Ports ------------------------
    output          gt0_eyescandataerror_out,
    input           gt0_eyescantrigger_in,
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    output  [31:0]  gt0_rxdata_out,
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    output  [3:0]   gt0_rxcharisk_out,
    output  [3:0]   gt0_rxdisperr_out,
    output  [3:0]   gt0_rxnotintable_out,
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    input           gt0_gtprxn_in,
    input           gt0_gtprxp_in,
    //------------ Receive Ports - RX Byte and Word Alignment Ports ------------
    output          gt0_rxbyteisaligned_out,
    output          gt0_rxbyterealign_out,
    output          gt0_rxcommadet_out,
    input           gt0_rxmcommaalignen_in,
    input           gt0_rxpcommaalignen_in,
    //---------- Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
    output  [14:0]  gt0_dmonitorout_out,
    //------------------ Receive Ports - RX Equailizer Ports -------------------
    input           gt0_rxlpmhfhold_in,
    input           gt0_rxlpmlfhold_in,
    //------------- Receive Ports - RX Fabric Output Control Ports -------------
    output          gt0_rxoutclkfabric_out,
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    input           gt0_gtrxreset_in,
    input           gt0_rxlpmreset_in,
    //--------------- Receive Ports - RX Polarity Control Ports ----------------
    input           gt0_rxpolarity_in,
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    output          gt0_rxresetdone_out,
    //------------------- TX Initialization and Reset Ports --------------------
    input           gt0_gttxreset_in,
    input           gt0_txuserrdy_in,
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    input   [31:0]  gt0_txdata_in,
    //---------------- Transmit Ports - TX 8B/10B Encoder Ports ----------------
    input   [3:0]   gt0_txcharisk_in,
    //------------- Transmit Ports - TX Configurable Driver Ports --------------
    output          gt0_gtptxn_out,
    output          gt0_gtptxp_out,
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    output          gt0_txoutclkfabric_out,
    output          gt0_txoutclkpcs_out,
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    output          gt0_txresetdone_out,

    //____________________________COMMON PORTS________________________________
   output     gt0_pll0reset_out,
    output          gt0_pll0outclk_out,
    output          gt0_pll0outrefclk_out,
    output          gt0_pll0lock_out,
    output          gt0_pll0refclklost_out,    
    output          gt0_pll1outclk_out,
    output          gt0_pll1outrefclk_out,
    input           sysclk_in

);


endmodule

