// -----------------------------------------------------------------------------
//  ____  ____
// /   /\/   /
///___/  \  /    Vendor: Xilinx
//\   \   \/     Version: 3.6
// \   \         Application: 7 Series FPGAs Transceivers Wizard
// /   /         Filename: gt_serial_telem_rx_subsystem.v
///___/   /\
//\   \  /  \
// \___\/\___\
//
// Module: gt_serial_telem_rx_subsystem
// Description:
//   Verilog translation of the provided VHDL subsystem. This module instantiates
//   the GT transceiver wrapper, drives basic RX/TX paths, exposes recovered data
//   and clocks, and optionally hooks up VIO/ILA debug cores.
//
// Notes:
//   - The original VHDL contained a number of commented-out components (frame
//     generator/checker). Those remain commented in intent; signals are preserved
//     for compatibility and debug purposes.
//   - "after DLY" timing in VHDL was modeling-only; converted here to standard
//     asynchronous reset flops without delays.
//   - Attributes like ASYNC_REG were added to appropriate registers.
//   - The GT wrapper (gt_serial_telem_rx), VIO (vio_0), ILA (ila_1, ila_gt_rx_0,
//     ila_8x8) are assumed to be available in your project/library.
//   - EXAMPLE_SIM_GTRESET_SPEEDUP is kept as an unused parameter for parity.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module gt_serial_telem_rx_subsystem #(
  // Configuration parameters (kept for parity with VHDL generics)
  parameter integer EXAMPLE_CONFIG_INDEPENDENT_LANES = 1,
  parameter integer EXAMPLE_LANE_WITH_START_CHAR     = 0,    // lane with unique start frame character
  parameter integer EXAMPLE_WORDS_IN_BRAM            = 512,  // amount of data in BRAM
  // Unused here, kept for compatibility with wizard-generated code
  // If your toolchain does not support string parameters, you may remove/ignore it
  //parameter string  EXAMPLE_SIM_GTRESET_SPEEDUP      = "FALSE",
  parameter integer STABLE_CLOCK_PERIOD              = 7,
  parameter integer EXAMPLE_USE_CHIPSCOPE            = 1,    // 1: use VIO to drive soft reset
  parameter integer G_DEBUG                          = 0     // debug flag (unused in this file)
)(
  // Reference clock for GT (125 MHz differential)
  input  wire Q0_CLK1_GTREFCLK_PAD_N_IN,
  input  wire Q0_CLK1_GTREFCLK_PAD_P_IN,

  // DRP/system clock domain (~128 MHz)
  input  wire DRP_CLK_IN,
  input  wire RST_128M,

  // Serial I/O
  input  wire RXN_IN,
  input  wire RXP_IN,
  output wire TXN_OUT,
  output wire TXP_OUT,

  // Parallel data outputs (recovered clock domain)
  output wire [31:0] DATA_OUT,
  output wire        DATA_CLK_OUT,    // recovered user clock (RXUSRCLK2)
  output wire [3:0]  DATA_IS_K_OUT,   // decoded K-character flags

  // Status/control
  output wire SOFT_RESET_OUT
);

  // ---------------------------------------------------------------------------
  // Tied constants
  // ---------------------------------------------------------------------------
  wire              tied_to_ground_i     = 1'b0;
  wire [63:0]       tied_to_ground_vec_i = 64'h0;
  wire              tied_to_vcc_i        = 1'b1;
  wire [7:0]        tied_to_vcc_vec_i    = 8'hFF;

  // ---------------------------------------------------------------------------
  // DRP/system clock alias
  // ---------------------------------------------------------------------------
  wire clk_128M = DRP_CLK_IN;

  // ---------------------------------------------------------------------------
  // GT wrapper signals
  // ---------------------------------------------------------------------------

  // DRP
  wire [8:0]  gt0_drpaddr_i;
  wire [15:0] gt0_drpdi_i;
  wire [15:0] gt0_drpdo_i;
  wire        gt0_drpen_i;
  wire        gt0_drprdy_i;
  wire        gt0_drpwe_i;

  // Status/locks
  wire gt0_txmmcm_lock_i;
  wire gt0_rxmmcm_lock_i;

  // FSM reset done indicators
  wire gt0_txfsmresetdone_i;
  wire gt0_rxfsmresetdone_i;

  // RX path
  wire [31:0] gt0_rxdata_i;
  wire [3:0]  gt0_rxcharisk_i;
  wire [3:0]  gt0_rxdisperr_i;
  wire [3:0]  gt0_rxnotintable_i;
  wire        gt0_rxbyteisaligned_out;
  wire        gt0_rxbyterealign_out;
  wire        gt0_rxcommadet_out;
  wire [14:0] gt0_dmonitorout_i;
  wire        gt0_rxoutclkfabric_i;
  wire        gt0_rxresetdone_i;

  // TX path
  wire [31:0] gt0_txdata_i = 0;
  wire [3:0]  gt0_txcharisk_i = 0;
  wire        gt0_txoutclkfabric_i;
  wire        gt0_txoutclkpcs_i;
  wire        gt0_txresetdone_i;

  // User clocks
  wire gt0_txusrclk_i;
  wire gt0_txusrclk2_i;
  wire gt0_rxusrclk_i;
  wire gt0_rxusrclk2_i;

  // Polarity/reset controls
  wire gt0_rxlpmreset_i;

  // Data valid path from checker to GT (as in VHDL; may be driven by checker)
  wire gt0_track_data_i = 0;

  // ---------------------------------------------------------------------------
  // Reset synchronization registers (modeled without delay)
  // ---------------------------------------------------------------------------
  // Registered/reset-synchronized versions of reset-done signals for user logic
  (* ASYNC_REG = "TRUE" *) reg gt0_txfsmresetdone_r  = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg gt0_txfsmresetdone_r2 = 1'b0;

  (* ASYNC_REG = "TRUE" *) reg gt0_rxresetdone_r  = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg gt0_rxresetdone_r2 = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg gt0_rxresetdone_r3 = 1'b0;

  // System resets for TX/RX user modules (active-high)
  wire gt0_tx_system_reset_c;
  wire gt0_rx_system_reset_c;

  // ---------------------------------------------------------------------------
  // Frame checker-related (kept for parity; checker is commented out)
  // ---------------------------------------------------------------------------
  wire        gt0_matchn_i = 0;              // from frame checker (pattern match)
  //wire [7:0]  gt0_error_count_i;         // from frame checker
  wire        gt0_frame_check_reset_i;   // reset control for checker
  wire        gt0_inc_in_i;              // increment control (tied low)
  //wire        gt0_inc_out_i;             // from checker
  wire        reset_on_data_error_i;     // unused in current context (tie low)

  assign reset_on_data_error_i = 1'b0;
  assign gt0_inc_in_i          = 1'b0;

  // Select checker reset source based on lane independence parameter
  assign gt0_frame_check_reset_i =
    (EXAMPLE_CONFIG_INDEPENDENT_LANES == 0) ? reset_on_data_error_i : gt0_matchn_i;

  // ---------------------------------------------------------------------------
  // Soft reset control (auto pulse at startup, optional VIO override)
  // ---------------------------------------------------------------------------
  reg  [15:0] soft_reset_cnt  = 16'h0000;
  reg         soft_reset_auto = 1'b0;
  wire [0:0]  soft_reset_vio_i = 0;
  wire        soft_reset_i;

  // Soft reset generation in DRP/system clock domain
  always @(posedge clk_128M) begin
    if (RST_128M) begin
      soft_reset_auto <= 1'b1;
      soft_reset_cnt  <= 16'h0000;
    end else if (soft_reset_cnt == 16'hFFFF) begin
      soft_reset_auto <= 1'b0;
    end else begin
      soft_reset_cnt  <= soft_reset_cnt + 16'h0001;
    end
  end

  // Combine auto reset and VIO-driven reset
  assign soft_reset_i  = soft_reset_auto | soft_reset_vio_i[0];
  assign SOFT_RESET_OUT = soft_reset_i;

  // ---------------------------------------------------------------------------
  // ChipScope/VIO generation (optional)
  // ---------------------------------------------------------------------------
  wire [0:0] gt0_rxfsmresetdone_s;
  assign gt0_rxfsmresetdone_s[0] = gt0_rxfsmresetdone_i;

//   generate
//     if (EXAMPLE_USE_CHIPSCOPE == 0) begin : gen_no_chipscope
//       // Tie off VIO output if not instantiated
//       assign soft_reset_vio_i = 1'b0;
//     end else begin : gen_chipscope
//       // VIO to drive soft reset
//       // vio_0 must be available in your project
//       vio_0 vio_gt_inst (
//         .clk       (clk_128M),
//         .probe_in0 (gt0_rxfsmresetdone_s),
//         .probe_out0(soft_reset_vio_i)
//       );
//     end
//   endgenerate

  // ---------------------------------------------------------------------------
  // Asynchronous reset synchronization for RX/TX user logic
  // ---------------------------------------------------------------------------
  // RX path reset-done synchronizer (active-low async reset)
  always @(posedge gt0_rxusrclk2_i or negedge gt0_rxresetdone_i) begin
    if (!gt0_rxresetdone_i) begin
      gt0_rxresetdone_r  <= 1'b0;
      gt0_rxresetdone_r2 <= 1'b0;
      gt0_rxresetdone_r3 <= 1'b0;
    end else begin
      gt0_rxresetdone_r  <= gt0_rxresetdone_i;
      gt0_rxresetdone_r2 <= gt0_rxresetdone_r;
      gt0_rxresetdone_r3 <= gt0_rxresetdone_r2;
    end
  end

  // TX FSM reset-done synchronizer (active-low async reset)
  always @(posedge gt0_txusrclk2_i or negedge gt0_txfsmresetdone_i) begin
    if (!gt0_txfsmresetdone_i) begin
      gt0_txfsmresetdone_r  <= 1'b0;
      gt0_txfsmresetdone_r2 <= 1'b0;
    end else begin
      gt0_txfsmresetdone_r  <= gt0_txfsmresetdone_i;
      gt0_txfsmresetdone_r2 <= gt0_txfsmresetdone_r;
    end
  end

  // Derive user module resets (active-high)
  assign gt0_tx_system_reset_c = ~gt0_txfsmresetdone_r2;
  assign gt0_rx_system_reset_c = ~gt0_rxresetdone_r3;

  // ---------------------------------------------------------------------------
  // Default/static assignments
  // ---------------------------------------------------------------------------
  assign gt0_rxlpmreset_i = 1'b0;

  assign gt0_drpaddr_i = 9'd0;
  assign gt0_drpdi_i   = 16'd0;
  assign gt0_drpen_i   = 1'b0;
  assign gt0_drpwe_i   = 1'b0;

  // ---------------------------------------------------------------------------
  // Data/clock outputs
  // ---------------------------------------------------------------------------
  assign DATA_OUT      = gt0_rxdata_i;
  assign DATA_CLK_OUT  = gt0_rxusrclk2_i;
  assign DATA_IS_K_OUT = gt0_rxcharisk_i;

  // ---------------------------------------------------------------------------
  // GT transceiver wrapper instantiation
  //   - This module is expected to be generated by Xilinx Transceiver Wizard.
//   - Ensure the port list matches your generated wrapper.
// ---------------------------------------------------------------------------
  gt_serial_telem_rx gt_serial_telem_rx_i (
    .soft_reset_tx_in            (soft_reset_i),
    .soft_reset_rx_in            (soft_reset_i),
    .dont_reset_on_data_error_in (tied_to_vcc_i),
    .q0_clk1_gtrefclk_pad_n_in   (Q0_CLK1_GTREFCLK_PAD_N_IN),
    .q0_clk1_gtrefclk_pad_p_in   (Q0_CLK1_GTREFCLK_PAD_P_IN),

    .gt0_tx_mmcm_lock_out        (gt0_txmmcm_lock_i),
    .gt0_rx_mmcm_lock_out        (gt0_rxmmcm_lock_i),
    .gt0_tx_fsm_reset_done_out   (gt0_txfsmresetdone_i),
    .gt0_rx_fsm_reset_done_out   (gt0_rxfsmresetdone_i),
    .gt0_data_valid_in           (gt0_track_data_i),

    .gt0_txusrclk_out            (gt0_txusrclk_i),
    .gt0_txusrclk2_out           (gt0_txusrclk2_i),
    .gt0_rxusrclk_out            (gt0_rxusrclk_i),
    .gt0_rxusrclk2_out           (gt0_rxusrclk2_i),

    // channel - drp ports
    .gt0_drpaddr_in              (gt0_drpaddr_i),
    .gt0_drpdi_in                (gt0_drpdi_i),
    .gt0_drpdo_out               (gt0_drpdo_i),
    .gt0_drpen_in                (gt0_drpen_i),
    .gt0_drprdy_out              (gt0_drprdy_i),
    .gt0_drpwe_in                (gt0_drpwe_i),

    // rx initialization/margin analysis
    .gt0_eyescanreset_in         (tied_to_ground_i),
    .gt0_rxuserrdy_in            (tied_to_vcc_i),
    .gt0_eyescandataerror_out    (/* unused */),
    .gt0_eyescantrigger_in       (tied_to_ground_i),

    // RX data interface
    .gt0_rxdata_out              (gt0_rxdata_i),

    // RX 8B/10B Decoder
    .gt0_rxcharisk_out           (gt0_rxcharisk_i),
    .gt0_rxdisperr_out           (gt0_rxdisperr_i),
    .gt0_rxnotintable_out        (gt0_rxnotintable_i),

    // RX serial inputs
    .gt0_gtprxn_in               (RXN_IN),
    .gt0_gtprxp_in               (RXP_IN),

    // RX byte/word alignment
    .gt0_rxbyteisaligned_out     (gt0_rxbyteisaligned_out),
    .gt0_rxbyterealign_out       (gt0_rxbyterealign_out),
    .gt0_rxcommadet_out          (gt0_rxcommadet_out),
    // Note: RXSLIDE disabled; enable comma align explicitly
    .gt0_rxmcommaalignen_in      (1'b1),
    .gt0_rxpcommaalignen_in      (1'b1),

    // RX equalizer/DFE
    .gt0_dmonitorout_out         (gt0_dmonitorout_i),
    .gt0_rxlpmhfhold_in          (tied_to_ground_i),
    .gt0_rxlpmlfhold_in          (tied_to_ground_i),

    // RX clocking/status
    .gt0_rxoutclkfabric_out      (gt0_rxoutclkfabric_i),
    .gt0_gtrxreset_in            (tied_to_ground_i),
    .gt0_rxlpmreset_in           (gt0_rxlpmreset_i),
    .gt0_rxresetdone_out         (gt0_rxresetdone_i),

    // TX reset/ready
    .gt0_gttxreset_in            (tied_to_ground_i),
    .gt0_txuserrdy_in            (tied_to_vcc_i),

    // TX data interface
    .gt0_txdata_in               (gt0_txdata_i),
    .gt0_txcharisk_in            (gt0_txcharisk_i),

    // TX serialized outputs
    .gt0_gtptxn_out              (TXN_OUT),
    .gt0_gtptxp_out              (TXP_OUT),

    // TX clocks/status
    .gt0_txoutclkfabric_out      (gt0_txoutclkfabric_i),
    .gt0_txoutclkpcs_out         (gt0_txoutclkpcs_i),
    .gt0_txresetdone_out         (gt0_txresetdone_i),

    // Common/PLL ports (unused here)
    .gt0_pll0reset_out           (/* open */),
    .gt0_pll0outclk_out          (/* open */),
    .gt0_pll0outrefclk_out       (/* open */),
    .gt0_pll0lock_out            (/* open */),
    .gt0_pll0refclklost_out      (/* open */),
    .gt0_pll1outclk_out          (/* open */),
    .gt0_pll1outrefclk_out       (/* open */),

    // RX polarity
    .gt0_rxpolarity_in           (1'b0),

    // System clock
    .sysclk_in                   (clk_128M)
  );

  // ---------------------------------------------------------------------------
  // Debug/ILA hookups
  // ---------------------------------------------------------------------------

  // // Pack RX data to 80b ( pad [79:32] with zeros, [31:0] data )
  // wire [79:0] gt0_rxdata_ila = {48'h0000_000000000, gt0_rxdata_i};

  // // RX data valid (padding both bits to 0, consistent with VHDL)
  // wire [1:0]  gt0_rxdatavalid_ila = 2'b00;

  // // Pack RX charisk to 8b (pad upper nibble with zeros)
  // wire [7:0]  gt0_rxcharisk_ila = {4'b0000, gt0_rxcharisk_i};

  // // Single-bit vectors for ILA
  // wire [0:0]  gt0_txmmcm_lock_ila = {gt0_txmmcm_lock_i};
  // wire [0:0]  gt0_rxmmcm_lock_ila = {gt0_rxmmcm_lock_i};
  // wire [0:0]  gt0_rxresetdone_ila = {gt0_rxresetdone_i};
  // wire [0:0]  gt0_txresetdone_ila = {gt0_txresetdone_i};

  // // Track data
  // wire        track_data_out_i    = gt0_track_data_i;
  // wire [0:0]  track_data_out_ila_i= {track_data_out_i};

//  // ILA for TX status (mmcm lock, resetdone)
//   ila_1 ila_tx0_inst (
//     .clk   (gt0_txusrclk_i),
//     .probe0(gt0_txmmcm_lock_ila),
//     .probe1(gt0_txresetdone_ila)
//   );

//   // ILA for RX data/control/status
//   ila_gt_rx_0 ila_rx0_inst (
//     .clk   (gt0_rxusrclk_i),
//     .probe0(gt0_rxdata_ila),
//     .probe1(gt0_error_count_i),
//     .probe2(track_data_out_ila_i),
//     .probe3(gt0_rxdatavalid_ila),
//     .probe4(gt0_rxcharisk_ila),
//     .probe5(gt0_rxmmcm_lock_ila),
//     .probe6(gt0_rxresetdone_ila)
//   );

  // // 8x8 ILAs for compact debug views
  // wire [7:0] probe0, probe1, probe2, probe3, probe4, probe5, probe6, probe7;
  // assign probe0 = { 1'b0, gt0_rxmmcm_lock_ila[0], gt0_rxresetdone_ila[0], track_data_out_ila_i[0],
  //                   gt0_rxresetdone_ila[0], gt0_rxcommadet_out, gt0_rxbyterealign_out, gt0_rxbyteisaligned_out };
  // assign probe1 = gt0_error_count_i;
  // assign probe2 = gt0_rxcharisk_ila;
  // assign probe3 = {5'b00000, gt0_frame_check_reset_i, gt0_matchn_i, gt0_inc_out_i};
  // assign probe4 = 8'h00;
  // assign probe5 = 8'h00;
  // assign probe6 = 8'h00;
  // assign probe7 = 8'h00;

//   ila_8x8 ila_8x8_inst (
//     .clk   (gt0_txusrclk_i),
//     .probe0(probe0),
//     .probe1(probe1),
//     .probe2(probe2),
//     .probe3(probe3),
//     .probe4(probe4),
//     .probe5(probe5),
//     .probe6(probe6),
//     .probe7(probe7)
//   );

  // wire [7:0] probe0_rx, probe1_rx, probe2_rx, probe3_rx, probe4_rx, probe5_rx, probe6_rx, probe7_rx;
  // assign probe0_rx = { 1'b0, gt0_rxmmcm_lock_ila[0], gt0_rxresetdone_ila[0], track_data_out_ila_i[0],
  //                      gt0_rxresetdone_ila[0], gt0_rxcommadet_out, gt0_rxbyterealign_out, gt0_rxbyteisaligned_out };
  // assign probe1_rx = gt0_error_count_i;
  // assign probe2_rx = gt0_rxcharisk_ila;
  // assign probe3_rx = {5'b00000, gt0_frame_check_reset_i, gt0_matchn_i, gt0_inc_out_i};
  // assign probe4_rx = {gt0_rxnotintable_i, gt0_rxdisperr_i};
  // assign probe5_rx = 8'h00;
  // assign probe6_rx = 8'h00;
  // assign probe7_rx = 8'h00;

//   ila_8x8 ila_8x8_rx_inst (
//     .clk   (gt0_rxusrclk_i),
//     .probe0(probe0_rx),
//     .probe1(probe1_rx),
//     .probe2(probe2_rx),
//     .probe3(probe3_rx),
//     .probe4(probe4_rx),
//     .probe5(probe5_rx),
//     .probe6(probe6_rx),
//     .probe7(probe7_rx)
//   );

  // ---------------------------------------------------------------------------
  // Notes on unused/transmit path:
  // - gt0_txdata_i and gt0_txcharisk_i are declared but not driven here.
  //   If TX is not used, leave them unconnected or drive as needed elsewhere.
  // ---------------------------------------------------------------------------

wire _unused_ok = 1'b0 && &{1'b0,
                    gt0_frame_check_reset_i, // todo: hook up to something other than ila
                    soft_reset_vio_i,
                    gt0_rxfsmresetdone_s,                    
                    gt0_inc_in_i,                    
                    gt0_matchn_i,
                    gt0_tx_system_reset_c,
                    gt0_track_data_i,
                    gt0_rxusrclk_i,
                    gt0_txresetdone_i,
                    gt0_txoutclkpcs_i,
                    gt0_txoutclkfabric_i,
                    gt0_txcharisk_i,
                    gt0_txdata_i,   
                    gt0_rx_system_reset_c,                   
                    gt0_txusrclk_i,
                    gt0_dmonitorout_i,
                    gt0_rxcommadet_out,
                    gt0_rxdisperr_i,
                    gt0_rxnotintable_i,
                    gt0_rxbyteisaligned_out,
                    gt0_rxbyterealign_out,
                    gt0_txmmcm_lock_i,
                    gt0_drprdy_i,
                    gt0_drpdo_i,
                    tied_to_vcc_i,
                    tied_to_vcc_vec_i,
                    tied_to_ground_vec_i,
                    //gt0_error_count_i,
                    gt0_matchn_i,
                    gt0_rxmmcm_lock_i,
                    gt0_rxoutclkfabric_i,
                    G_DEBUG,
                    EXAMPLE_USE_CHIPSCOPE,
                    STABLE_CLOCK_PERIOD,
                    EXAMPLE_WORDS_IN_BRAM,
                    EXAMPLE_LANE_WITH_START_CHAR,
                    1'b0};

endmodule


`resetall
