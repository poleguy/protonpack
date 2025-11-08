// file: ibert_7series_gtp_0.v
//////////////////////////////////////////////////////////////////////////////
//
// Reference example_ibert_7series_gtp_0 generated from IBERT IP
//
// 
// Take in fixed 200MHz SYSCLK and use as general perpose guaranteed clock
// and also use it to create slower clock via mmcm to use for i2c module.
//
// Program si570 part over i2c to provide a configurable clock (128MHz) into
// pins user_clk_p/n.
//
// Route the 128MHz clock from user_clk to rec_clock.. this rec_clock is then 
// routed on the board to the gtp refclk 0 via mux select lines SFP_CLK_SEL0/1.
//
// 
//////////////////////////////////////////////////////////////////////////////

`default_nettype none // do not use implicit wire for port connections

//`define INCLUDE_PCAPNG  1
`define C_NUM_QUADS 1
`define C_REFCLKS_USED 1
module telem_mobile_ac701
#(
  parameter g_SIM = 1'b0,
// parameter g_link_wait = 1'b1,
 parameter g_debug = 1'b0) (
 
  // GT top level ports
//  output [(4*`C_NUM_QUADS)-1:0]		TXN_O,
//  output [(4*`C_NUM_QUADS)-1:0]		TXP_O,
//  input  [(4*`C_NUM_QUADS)-1:0]    	RXN_I,
//  input  [(4*`C_NUM_QUADS)-1:0]   	RXP_I,
//  input                           	SYSCLKP_I,

// these must be removed if not used, to prevent this:                            
//ERROR: [DRC UCIO-1] Unconstrained Logical Port: 2 out of 32 logical ports have no user assigned specific location constraint (LOC). This may cause I/O contention or incompatibility with the board power or connectivity affecting performance, signal integrity or in extreme cases cause damage to the device or the components to which it is connected. To correct this violation, specify all pin locations. This design will fail to generate a bitstream unless all logical ports have a user specified site LOC constraint defined.  To allow bitstream creation with unspecified pin locations (not recommended), use this command: set_property SEVERITY {Warning} [get_drc_checks UCIO-1].  NOTE: When using the Vivado Runs infrastructure (e.g. launch_runs Tcl command), add this command to a .tcl file and add that file as a pre-hook for write_bitstream step for the implementation run.  Problem ports: TXN_O, and TXP_O.

//  output   wire                   TXN_O, 
//  output   wire                   TXP_O,
  input    wire                   RXN_I,  // these magically do not need a IOSTANDARD or PACKE_PIN constraint?
  input    wire                   RXP_I,
  input    wire                   SYSCLKP_I, // 200MHz input from oscillator on board
  input    wire                   SYSCLKN_I,
  input    wire                   user_clk_p, // 128MHz input from synthesizer chip
  input    wire                   user_clk_n,
  input wire [`C_REFCLKS_USED-1:0] GTREFCLK0P_I, // 125MHz Unused
  input wire [`C_REFCLKS_USED-1:0] GTREFCLK0N_I,
  input wire [`C_REFCLKS_USED-1:0] GTREFCLK1P_I, // 128MHz looped back via SMA cables
  input wire [`C_REFCLKS_USED-1:0] GTREFCLK1N_I,
  output  wire                    REC_CLOCK_P,
  output  wire                    REC_CLOCK_N,
 // output USER_SMA_GPIO_P,
 // output USER_SMA_GPIO_N,
  output  wire                    USER_SMA_CLK_P,  // 128MHz output to loop back SMA
  output  wire                    USER_SMA_CLK_N,
  output  wire                    SFP_CLK_SEL0,
  output  wire                    SFP_CLK_SEL1,
  output  wire                    SFP_CLK1_SEL0,
  output  wire                    SFP_CLK1_SEL1,
  output  wire                    IIC_SCL_MAIN,//N18
  inout   wire                    IIC_SDA_MAIN, //K25

// Ethernet PHY MII


  output      wire                PHY_RESET_B,

  output          wire            PHY_MDC, // not used
//  inout                       PHY_MDIO, // not used
  input      wire                 PHY_MDIO, // not used can't use inout without a warning
 
  output     wire                 PHY_TX_CLK,
  output     wire                 PHY_TX_CTRL,
  output     wire                 PHY_TXD3,
  output     wire                 PHY_TXD2,
  output     wire                 PHY_TXD1,
  output     wire                 PHY_TXD0,

                                // not used
  input      wire                 PHY_RX_CLK,
  input      wire                 PHY_RX_CTRL,
  input      wire                 PHY_RXD3,
  input      wire                 PHY_RXD2,
  input      wire                 PHY_RXD1,
  input      wire                 PHY_RXD0,

  output     wire                 PMOD_0,
  output     wire                 PMOD_1,
  output     wire                 PMOD_2,
  output     wire                 PMOD_3,

  output     wire                 GPIO_LED_0,
  output     wire                 GPIO_LED_1

);

  // define input/output wires explicitly to satisfy default_nettype none requirement and avoid a typo causing a silent mistake

   // cause the system to wait until the ethernet is ready before starting to send telemetry to the ethernet block
   wire                           g_link_wait;
    

  //
  // Ibert refclk internal signals
  //
//   wire [`C_NUM_QUADS-1:0]    gtrefclk0_i;
//   wire [`C_NUM_QUADS-1:0]    gtrefclk1_i;
//   wire [`C_REFCLKS_USED-1:0] refclk0_i;
  //wire   [`C_REFCLKS_USED-1:0]      refclk1_i;
   wire                       clk_200M;

   wire                       i2c_done;

//   wire [15:0]                _200MHz_SYSCLK_o; //200MHz
//   wire [19:0]                _200MHz_SYSCLK; //200MHz
//   wire [15:0]                _Si570_USER_CLK_o; //128MHz
//   wire [15:0]                _GT_CLK_o; //128MHz
//   wire [15:0]                _GT_CLK1_o; //128MHz
//   wire [19:0]                _Si570_USER_CLK; //128MHz
//   wire [19:0]                _GT_REF_CLK; //128MHz
//   wire [19:0]                _GT_REF_CLK1; //128MHz

//  wire clk_gt_128M;
//  wire clk_gt1_128M;
//   wire                       clk_gt0_odiv2;
   wire                       clk_125M;
   wire                       user_clk;
   wire                       clk_128M;
   wire                       clk_20M;

   wire                       i2c_rst;
   reg                        vio_i2c_rst = 1'b0;

   //todo: hook to smi config?
   reg                        eth_link_up = 1'b1;

   wire                       clk_wiz_locked;
   reg                        r_soft_reset_125M = 1'b0;
   reg                        r1_soft_reset_125M = 1'b0;
   reg                        r_clk_wiz_locked_128M = 1'b0;
   reg                        r1_clk_wiz_locked_128M = 1'b0;
   reg                        r_clk_wiz_locked_125M = 1'b0;
   reg                        r1_clk_wiz_locked_125M = 1'b0;
   reg                        r_clk_wiz_locked_256M = 1'b0;
   reg                        r1_clk_wiz_locked_256M = 1'b0;
   reg                        r_rst_128M = 1'b0;
   reg                        r_rst_256M = 1'b0;
   reg                        r_rst_125M = 1'b0;
   
   wire                       clk_256M;
   wire                       clk_25M;
//   wire                       gt_data_valid;
   wire [31:0]                gt_data;
   wire [3:0]                 gt_data_is_k;
   wire [87:0]                packet_data;
   wire                       packet_valid;

   wire                       stream_clk0;
   wire                       stream_valid0;
   wire [31:0]                stream_enable0;
   wire [87:0]                stream_data0;


   wire [7:0]                 eth_tdata;
   wire                       eth_tvalid;
   wire                       eth_tlast;
   wire                       eth_tready;
   wire [15:0]                eth_len;
   wire [15:0]                eth_ip_id;
   wire [15:0]                eth_udp_dest;
   wire                       eth_telem_en;
   





//   wire [31:0]                stream_ts0;
	   

//   wire                       sys_time_clk;
//   wire                       rst_sys_time_clk;

   reg                        r_rst_125M_telemetry = 1'b0;

   wire                       gmii_tx_en;
   wire [7:0]                 gmii_txd;
   
   wire [3:0]                 rgmii_txd;
   wire                       rgmii_tx_ctl;
   wire                       rgmii_txc;
   
   wire                       gt_clk;

   // reset the packet counters
   reg reset_counters = 0;
   wire [31:0] total_packets;
   wire [31:0] mismatch_packets;

   wire                       okay_led;
   wire                       link_count_okay;
   wire                       gt_soft_reset;

   wire [47:0]                tx_mac_dest;
   


   // choose the mux input from si5324 device 0x1
   assign SFP_CLK_SEL0 = 1'b1;
   assign SFP_CLK_SEL1 = 1'b0;

   // choose SMA ref clock input 0x0
   assign SFP_CLK1_SEL0 = 1'b0;
   assign SFP_CLK1_SEL1 = 1'b0;

   // rename phy signals to match xilinx default xdc/schematic names
   assign PHY_TXD3 = rgmii_txd[3];
   assign PHY_TXD2 = rgmii_txd[2];
   assign PHY_TXD1 = rgmii_txd[1];
   assign PHY_TXD0 = rgmii_txd[0];
   
   assign PHY_TX_CTRL = rgmii_tx_ctl;
   assign PHY_TX_CLK = rgmii_txc;

   assign PMOD_0 = clk_125M;
   assign PMOD_1 = r_rst_128M;
   assign PMOD_2 = r_rst_125M_telemetry;
   assign PMOD_3 = r_rst_125M;

   assign GPIO_LED_0 = okay_led;
   assign GPIO_LED_1 = link_count_okay;


   assign PHY_RESET_B = ~r_rst_125M;

   // drive constant output: not used
   assign PHY_MDC = 1'b0;
//   assign TXN_O = 1'b0;
//   assign TXP_O = 1'b0;
   
   //    // not in use, but this goes here to prevent this warning:
   // WARNING: [Synth 8-3848] Net PHY_MDIO ... does not have driver.
   //assign PHY_MDIO = 1'bZ;
   
   
   
   
   parameter FREQ_CNT_VAL = 16'h0800;  //was 0x4000 for 200MHz clock, 0x800 for 25MHz


  //200Mhz to 20Mhz (for i2c)
  clk_wiz_200M clk_wiz_200M_i
  (
      .clk_in1 (clk_200M),
      .clk_out1 (clk_25M),
      .clk_out2 (clk_20M),
      .clk_out3 (clk_125M),
      .locked (clk_wiz_locked)
  );

  assign i2c_rst = vio_i2c_rst || ~clk_wiz_locked;
  i2c_clk_cfg i2c_clk_cfg_i
  (
    .clk  (clk_20M),
    .rst  (i2c_rst),
    .scl  (IIC_SCL_MAIN),  
    .sda  (IIC_SDA_MAIN),  
    .done (i2c_done)
    );

//   create reset in 128M clock domain

   always @(posedge clk_128M)
     begin
        r_clk_wiz_locked_128M <= clk_wiz_locked;
        r1_clk_wiz_locked_128M <= r_clk_wiz_locked_128M;
        
        if (r1_clk_wiz_locked_128M == 0)
		  // reset until first MMCM is locked
          r_rst_128M <= 1;
        else
          r_rst_128M <= 0;
     end

   always @(posedge clk_125M)
     begin
        r_clk_wiz_locked_125M <= clk_wiz_locked;
        r1_clk_wiz_locked_125M <= r_clk_wiz_locked_125M;

        r_soft_reset_125M <= gt_soft_reset;
        r1_soft_reset_125M <= r_soft_reset_125M;
        
        if (r1_clk_wiz_locked_125M == 0)
		  // reset until first MMCM is locked
		  r_rst_125M <= 1;
        else
          r_rst_125M <= 0;
     end

   always @(posedge clk_256M)
     begin
        r_clk_wiz_locked_256M <= clk_wiz_locked;
        r1_clk_wiz_locked_256M <= r_clk_wiz_locked_256M;
        
        if (r1_clk_wiz_locked_256M == 0)
          r_rst_256M <= 1;
        else
          r_rst_256M <= 0;
     end

   // todo: 125MHz add an ibufds_gte2 to get the clock into the fabric
   // o should go directly into the fabric
   // so long as the output does not go to a transceiver
   // in ultrascale plus odiv2 is not divided by two. it's just a duplicate output.

//    IBUFDS_GTE2 u_buf_q0_clk1
//      (
//        .O            (clk_125M),
//        .ODIV2        (clk_gt0_odiv2),
//        .CEB          (1'b0),
//        .I            (GTREFCLK0P_I[0]),
//        .IB           (GTREFCLK0N_I[0])
//      );
   
    /*
  //
  // Refclk IBUFDS instantiations
  //

    IBUFDS_GTE2 u_buf_q0_clk0
      (
        .O            (refclk0_i[0]),
        .ODIV2        (clk_gt_128M),
        .CEB          (1'b0),
        .I            (GTREFCLK0P_I[0]),
        .IB           (GTREFCLK0N_I[0])
      );


  //
  // Refclk connection from each IBUFDS to respective quads depending on the source selected in gui
  //
  assign gtrefclk0_i[0] = refclk0_i[0];
  assign gtrefclk1_i[0] = refclk1_i[0];
  */
  //
  // Sysclock IBUFDS instantiation
  //
  IBUFGDS 
   #(.DIFF_TERM("FALSE"))
   ibufgds_sysclk
    (
      .I(SYSCLKP_I),
      .IB(SYSCLKN_I),
      .O(clk_200M)
    );

  IBUFGDS 
   #(.DIFF_TERM("FALSE"))
   ibufgds_userclk
    (
      .I(user_clk_p),
      .IB(user_clk_n),
      .O(user_clk)
    );

    BUFG bufg_userclk
    (
        .O(clk_128M),
        .I(user_clk)
    );

  OBUFDS #(
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("FAST")           // Specify the output slew rate
   ) OBUFDS_REC_CLOCK (
      .O(REC_CLOCK_P),     // Diff_p output (connect directly to top-level port)
      .OB(REC_CLOCK_N),   // Diff_n output (connect directly to top-level port)
      .I(clk_128M)      // Buffer input
   );


   // generate user_CLOCK_N/P from Si570 programmable oscillator on board at 128M
   // route in fabric to output sma connectors.
   // sma back in on J23/H23 USER_CLOCK_N
  OBUFDS #(
      .IOSTANDARD("DEFAULT"), // Specify the output I/O standard
      .SLEW("FAST")           // Specify the output slew rate
   ) OBUFDS_USER_SMA (
      .O(USER_SMA_CLK_P),     // Diff_p output (connect directly to top-level port)
      .OB(USER_SMA_CLK_N),   // Diff_n output (connect directly to top-level port)
      .I(clk_128M)      // Buffer input
   );

// found in rtl/gt_support/gt_serial_telem_rx_subsystem.vhd
  gt_serial_telem_rx_subsystem gt_serial_telem_rx_subsystem
  (
    .Q0_CLK1_GTREFCLK_PAD_N_IN  (GTREFCLK1N_I[0]),
    .Q0_CLK1_GTREFCLK_PAD_P_IN  (GTREFCLK1P_I[0]), // 128 reference in from mux on board from GTP SMA J25(p)/J26(N)
    .DRP_CLK_IN                 (clk_128M), // dynamic reconfiguration port routed from external sma because it can't be routed from the fabric.
    .RST_128M                 (r_rst_128M),
    .SOFT_RESET_OUT           (gt_soft_reset),
    .RXN_IN                      (RXN_I),
    .RXP_IN                      (RXP_I),

    .TXN_OUT                     (), // not used
    .TXP_OUT                     (),
      // this data comes out at the rxusrclk2 rate (32MHz)
    .data_clk_out (gt_clk),
    .data_out   (gt_data),
    .data_is_k_out (gt_data_is_k)
  );

   // reclock in to 256M domain
   // because 128M domain is asynchronous and might not be fast enough
// always @(posedge clk_256M)
//   begin
//      r_gt_clk <= gt_clk;
//      r1_gt_clk <= r_gt_clk;
//      r2_gt_clk <= r1_gt_clk;
//      
//      // rising edge of slow clock
//      if (~r2_gt_clk && r1_gt_clk) begin
//         r_gt_data <= gt_data;
//         r_gt_data_is_k <= gt_data_is_k;
//         r_gt_data_valid <= 1'b1;
//      end else begin
//         r_gt_data_valid <= 1'b0;
//      end
// end


   
   // telemetry module
   // pulls in 32bit data and control
   // spits out packet data ready for ethernet
   // rtl/serial_link/gt_unpack_telemetry.vhd
  gt_unpack_telemetry gt_unpack_telemetry
  (
    .CLK_128M                 (clk_128M),
    .RST_128M                 (r_rst_128M),
    .gt_clk                   (gt_clk),
    .gt_data                  (gt_data),
    .gt_data_is_k             (gt_data_is_k),
    .clk_256m_out (clk_256M),
    .pll_locked_out (),
    .okay_led_out (),
    .cnt_led_out (),
   // 11 byte outputs and control status signals, in clk_256M domain
    .DATA_OUT                   (packet_data),
    .VALID_OUT                     (packet_valid)
  );


   telemetry_check telemetry_check
     (
      .clk_256M    (clk_256M),
      .packet_data (packet_data),
      .packet_valid (packet_valid),
      .reset_counters (reset_counters),
      .total_packets (total_packets),
      .mismatch_packets (mismatch_packets),
      .okay_led (okay_led),
      .link_count_okay (link_count_okay)
      );

   
   
   // we use records for telemetry module is this a problem with verilog?

//-------------------------------------------------------------------------------
//-- Ethernet Telemetry
//-------------------------------------------------------------------------------

  // so add a a vhd wrapper to handle records/types into ethernet-telemetry
  // to work with .v

  
 // rtl/serial_link/ethernet_telemetry_subsystem
 ethernet_telemetry_subsystem #()
 ethernet_telemetry_subsystem
   (
     .eth_rst      (r_rst_125M_telemetry),
     .eth_clk      (clk_125M),
     .eth_tdata    (eth_tdata),
     .eth_tvalid   (eth_tvalid),
     .eth_tlast    (eth_tlast),
     .eth_tready   (eth_tready),
     .eth_len      (eth_len),
     .eth_ip_id    (eth_ip_id),
     .eth_udp_dest (eth_udp_dest),
     .eth_telem_en (eth_telem_en),

     .clk_128M      (clk_128M),
     .clk_256M      (clk_256M),
     .mobile_pkt_data(packet_data),
     .mobile_pkt_data_val(packet_valid)
     );


// data from tx

   assign g_link_wait = ~g_SIM; // don't wait in sim for the link to be ready because there is no hardware to wait for
//always @(g_link_wait or eth_link_up)
//  begin
//     if (g_link_wait == 1)
    assign eth_telem_en = (g_link_wait & eth_link_up) | (~g_link_wait);
//     else
//       eth_telem_en = 1;
//  end
   


always @(posedge clk_125M)
 begin
   //-- reset every time the link goes down
     if (g_link_wait == 0) begin
       //-- in sim, dummy this out to start right away.
       r_rst_125M_telemetry <= r_rst_125M;
     end else begin
       //-- on hardware, wait for the link to come up
       //-- so that the fifo doesn't end up with partial 
       //-- data in it.
       r_rst_125M_telemetry <= r_rst_125M | ~eth_link_up;
     end

 end

  vio_eth vio_eth (
    .clk(clk_125M),           // input wire clk
    .probe_out0(tx_mac_dest)  // output wire [47 : 0] probe_out0
  );


// sys_time_clk <= stream_clk0;
// ./modules/ethernet-telemetry/fpga/rtl/eth_udp_mac/eth_udp_mac_tx.vhd
 eth_udp_mac_tx eth_udp_mac_tx
   (
     .rst         (r_rst_125M),
     .clk         (clk_125M),
     .mac_gmii_en (1'b1),
     
     .cfg_src_mac_addr (48'h5A0001020304),
     .cfg_ip_src_addr  (32'hAABBCCDD),
     
     .tx_mac_dest    (tx_mac_dest),
     .tx_ip_id       (eth_ip_id),
     .tx_payload_len (eth_len),
     .tx_ip_dest     (32'hFFFFFFFF),
     .tx_udp_src     (16'h0000),
     .tx_udp_dest    (eth_udp_dest),
     
     .s_axis_tdata  (eth_tdata),
     .s_axis_tvalid (eth_tvalid),
     .s_axis_tlast  (eth_tlast),
     .s_axis_tready (eth_tready),
     
     .txd_en (gmii_tx_en),
     .txd    (gmii_txd)
     );


   // could also use telem_eval_ax7a035/rtl/packet_gen/eth/util_gmii_to_rgmii.v
   // which also handles rx side and other signals
   // but this is here and works
  // modules/ethernet-telemetry/fpga/rtl/eth_udp_mac/gmii_to_rgmii.vhd
  gmii_to_rgmii gmii_to_rgmii
    (
        .clk            (clk_125M),
                       
        .gmii_txd_en    (gmii_tx_en),
        .gmii_tx_er     (gmii_tx_en), //put tx_en in here for both clock edge for now, not using _er
        .gmii_txd       (gmii_txd),
                       
        .rgmii_txd      (rgmii_txd),
        .rgmii_tx_ctl   (rgmii_tx_ctl),
        .rgmii_txc      (rgmii_txc)
  );
   

   
   
   // todo: 125M comes from U3 mux. ON by default
   // mux state 00
   // CLK0_GTREFCLK

  //
  // IBERT core instantiation
  //
  //
  /*
  ibert_7series_gtp_0 u_ibert_core
    (
      .TXN_O(TXN_O),
      .TXP_O(TXP_O),
      .RXN_I(RXN_I),
      .RXP_I(RXP_I),
      .SYSCLK_I(clk_200M),
      .GTREFCLK0_I(gtrefclk0_i),
      .GTREFCLK1_I(gtrefclk1_i)
    );
    */

    /*
    ibert_freq_counter freq_counter1
      (.FREQ_CNT_O (_200MHz_SYSCLK_o),
       .RST_I (1'b0),
       .TEST_TERM_CNT_I (FREQ_CNT_VAL),
       .REF_CLK_I (clk_25M),
       .TEST_CLK_I (clk_200M)
        );

    ibert_freq_mult freq_mult1
      (.FREQ_CNT_COR (_200MHz_SYSCLK),
       .RST_I (1'b0),
       .INPUT (_200MHz_SYSCLK_o),
       .REF_CLK_I (clk_25M)
        );

    ibert_freq_counter freq_counter2
      (.FREQ_CNT_O (_Si570_USER_CLK_o),
       .RST_I (1'b0),
       .TEST_TERM_CNT_I (FREQ_CNT_VAL),
       .REF_CLK_I (clk_25M),
       .TEST_CLK_I (clk_128M)
        );
       
    ibert_freq_mult freq_mult2
      (.FREQ_CNT_COR (_Si570_USER_CLK),
       .RST_I (1'b0),
       .INPUT (_Si570_USER_CLK_o),
       .REF_CLK_I (clk_25M)
        );

    ibert_freq_counter freq_counter3
      (.FREQ_CNT_O (_GT_CLK_o),
       .RST_I (1'b0),
       .TEST_TERM_CNT_I (FREQ_CNT_VAL),
       .REF_CLK_I (clk_25M),
       .TEST_CLK_I (clk_gt_128M)
        );
       
    ibert_freq_mult freq_mult3
      (.FREQ_CNT_COR (_GT_REF_CLK),
       .RST_I (1'b0),
       .INPUT (_GT_CLK_o),
       .REF_CLK_I (clk_25M)
        );

    ibert_freq_counter freq_counter4
      (.FREQ_CNT_O (_GT_CLK1_o),
       .RST_I (1'b0),
       .TEST_TERM_CNT_I (FREQ_CNT_VAL),
       .REF_CLK_I (clk_25M),
       .TEST_CLK_I (refclk1_i[0])
        );
       
    ibert_freq_mult freq_mult4
      (.FREQ_CNT_COR (_GT_REF_CLK1),
       .RST_I (1'b0),
       .INPUT (_GT_CLK1_o),
       .REF_CLK_I (clk_25M)
        );

    vio_0 VIO_INST
    (
      .clk         (clk_200M),
      .probe_in0   (_Si570_USER_CLK),
      .probe_in1   (_200MHz_SYSCLK),
      .probe_in2   (_GT_REF_CLK),
      .probe_in3   (_GT_REF_CLK1),
      .probe_out0  (vio_i2c_rst)
    );
    */

//  `ifdef INCLUDE_PCAPNG
   if (g_SIM == 1'b1) begin
        tb_rgmii_to_pcapng tb_rgmii_to_pcapng
        (
            .clk(rgmii_txc),
            .rgmii(rgmii_txd),
            .rgmii_ctrl(rgmii_tx_ctl)
        );
   end   
//  `endif


endmodule

`resetall
