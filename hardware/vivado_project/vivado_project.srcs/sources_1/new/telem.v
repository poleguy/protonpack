`timescale 1ns / 1ps
`default_nettype none // do not use implicit wire for port connections

module telem
  #(
     //   parameter integer STREAM0_VAL_COUNT = 3815,
     //   parameter integer STREAM1_VAL_COUNT = 59,
     //   parameter integer STREAM2_VAL_COUNT = 238,
     //  parameter g_debug = 1, // boolean as integer 0 or 1
     //  parameter g_link_wait = 1 // boolean as integer 0 or 1
     parameter g_match_cnt = 19'h4ffff,
     parameter g_timeout_cnt = 16'hffff,
     parameter g_debug = 1
   )
   (
     //input push_rst,
     input wire clk_80M,
     input wire clk_52M,
     //input wire clk_200M,

     input wire serial_in_p,
     input wire serial_in_n,

     output wire okay_led_out,
     output wire rst_80M,

     output wire [31:0] sb_data_rd,
     input wire [31:0] sb_data_wr,
     input wire [23:0] sb_addr,
     input wire sb_wea ,
     input wire sb_rea,
     output wire pll_locked,
     output wire rx_dat_aligned

   );

  // More signals declaration similar to VHDL

  wire [3:0] alignment_out;
  wire rx_data_ready;
  wire [9:0]rx_data_raw;
  reg [31:0] sb_data_rd_mux;

  wire serial_in_buf_p;
  wire serial_in_buf_n;
  reg r_rst_self_80M_n = 0;
  reg [4:0] r_rst_self_cnt_80M = 0;
  wire okay_led;
  wire cnt_led_out;
  wire [87:0] data_out;
  wire [95:0] fifo_data_out;
  wire valid_out;
  wire clk_200M;
  wire empty;
  wire full;
  reg fifo_read_en = 1'b0;
  reg [31:0] r_sb_regs_rd = 32'h0;
  wire [31:0] sb_data_rd;
  reg [31:0] rd_count = 32'h0;
  wire [31:0] logger_data_in;
  wire [31:0] ila_logger_data;

  // Internal registers for storage
  reg [31:0] memory [0:3]; // Memory array for locations 0, 1, 2, and 3

  wire one = 1'b1;

  reg [95:0] fifo_in;
  reg [7:0] wr_count = 8'h0;
  reg [31:0] integrated_wr_count = 32'h0;
  reg fifo_valid = 1'h0;


// Abandoned approach:
//  Ugh: after spending all morning working on the designed based on pg047 I think I'm coming to the conclusion that the data and clocks are required to be strictly synchronous between tx and rx, which won't work for ar rx only solution.
// https://docs.amd.com/r/en-US/pg047-gig-eth-pcs-pma/LVDS-Transceiver-for-7-Series-and-Zynq-7000-Devices
// AMD Technical Information Portal
// I'd love for someone to tell me I'm wrong, but in their verilog the output of the final 6b_10b gearbox has only a 125MHz clock (exactly 1/10th the line rate) and the rxdata_10b output data with no valid signal. So that's a non-starter. 
 
//   // Signals for Transceiver Receiver Interface
//   wire          my_rxchariscomma;
//   wire          my_rxcharisk;
//   wire [7:0]    my_rxdata;
//   wire          my_rxdisperr;
//   wire          my_rxnotintable;
//   wire          my_rxrundisp;
//   wire          my_rxbuferr;

//   // Signals for Clocks and Reset
//   wire          my_phy_cdr_lock;
//   wire          my_soft_rx_reset;
//   wire          my_reset;

//   // Signals for Margin Control and Eye Monitor
//   wire [4:0]    my_o_r_margin;
//   wire [4:0]    my_o_l_margin;
//   wire [11:0]   my_eye_mon_wait_time;

//   // Signals for Serial Differential Pairs
//   wire          my_pin_sgmii_rxn;
//   wire          my_pin_sgmii_rxp;


//   assign my_reset = ~r_rst_self_80M_n;
//   assign my_soft_rx_reset = 1`b0;
//   // Instance of the block_design_gig_ethernet_pcs_pma_0_0_lvds_transceiver_k7 module
//   rx_lvds rx_lvds_0 (
//     .rxchariscomma       (my_rxchariscomma),
//     .rxcharisk           (my_rxcharisk),
//     .rxdata              (data_out),
//     .rxdisperr           (my_rxdisperr),
//     .rxnotintable        (my_rxnotintable),
//     .rxrundisp           (my_rxrundisp),
//     .rxbuferr            (my_rxbuferr),

//     .phy_cdr_lock        (my_phy_cdr_lock),
//     .clk512              (my_clk512),
//     .clk170p3936              (clk170p3936),
//     .clk85p1968              (clk85p1968),
//     .clk102p4              (my_clk102p4),
//     .soft_rx_reset       (my_soft_rx_reset),
//     .reset               (my_reset),

//     .o_r_margin          (my_o_r_margin),
//     .o_l_margin          (my_o_l_margin),

//     .eye_mon_wait_time   (my_eye_mon_wait_time),

//     .pin_sgmii_rxn       (serial_in_buf_n),
//     .pin_sgmii_rxp       (serial_in_buf_p)
//   );

  always @(posedge clk_80M)
  begin
    // Check if reset counter has reached its max value
    if (r_rst_self_cnt_80M == 5'b11111)
    begin
      r_rst_self_80M_n <= 1'b1;
    end
    else
    begin
      r_rst_self_cnt_80M <= r_rst_self_cnt_80M + 5'b00001;
    end
  end

  assign rst_80M = ~r_rst_self_80M_n;

  assign okay_led_out = okay_led;

  //-- xapp523 based receiver

  //-- ---------------------------------------------------------------------------------------------
  //---- LVDS Receiver
  //-----------------------------------------------------------------------------------------------


  IBUFDS_DIFF_OUT IBUFDS_DIFF_OUT_SERIAL_IN_inst (
                    .O(serial_in_buf_p),
                    .OB(serial_in_buf_n),
                    .I(serial_in_p),
                    .IB(serial_in_n)
                  );


  check_telemetry #(
                    .g_debug(g_debug),
                    .g_match_cnt(g_match_cnt),
                    .g_timeout_cnt(g_timeout_cnt)
                  ) check_telemetry_1 (
                    .clk_80M(clk_80M),
                    .rst_80M(rst_80M),
                    .clk_200M_out(clk_200M),
                    .pll_locked_out(pll_locked),
                    .serial_in_n(serial_in_buf_n),
                    .serial_in_p(serial_in_buf_p),
                    .okay_led_out(okay_led), // Internal 200 MHz clock domain
                    .cnt_led_out(cnt_led_out), // Internal 200 MHz clock domain
                    .data_out(data_out), // Internal 200 MHz clock domain
                    .valid_out(valid_out), // Internal 200 MHz clock domain
                    .rx_dat_aligned(rx_dat_aligned),
                    .alignment_out(alignment_out),
                    .rx_data_ready(rx_data_ready),
                    .rx_data_raw(rx_data_raw)
                  );


  always @(posedge clk_200M)
  begin
    if (valid_out)
    begin
      integrated_wr_count <= integrated_wr_count+1;
    end
  end


  always @(posedge clk_200M)
  begin
    if (valid_out)
    begin
      wr_count <= wr_count+1;
      fifo_in <= {wr_count, data_out};
    end
    fifo_valid <= valid_out;
  end



  // to sanity check how fast we can read from linux
  always @(posedge clk_52M)
  begin
    rd_count <= rd_count+1;
  end


  // Instance of the FIFO module
  afifo fifo_inst (
          .i_wclk(clk_200M),
          .i_wrst_n(one),
          .i_rclk(clk_52M),
          .i_rrst_n(one),
          .i_wr(fifo_valid),
          .i_rd(fifo_read_en),
          .i_wdata(fifo_in),
          .o_rdata(fifo_data_out),
          .o_rempty(empty),
          .o_wfull(full)
        );


  always @(posedge clk_52M)
  begin
    begin
      // Write to memory if write_en is high
      if (sb_wea    )
      begin
        case (sb_addr[3:0])
          4'h0:
            memory[0] <= sb_data_wr;
          4'h1:
            memory[1] <= sb_data_wr;
          4'h2:
            memory[2] <= sb_data_wr;
          4'h3:
            memory[3] <= sb_data_wr;
        endcase
      end

      fifo_read_en <= 1'b0;
      // Read data from appropriate memory location
      // ignore bottom two bits of sb_addr which are byte addresses
      case (sb_addr[10:2])
        9'h0:
          r_sb_regs_rd <= 32'h0000000e; // version
        9'h1:
          r_sb_regs_rd <= rd_count;
        9'h2:
          r_sb_regs_rd <= integrated_wr_count;
        9'h3:
          r_sb_regs_rd <= memory[3];
        9'h4:
          r_sb_regs_rd <= fifo_data_out[31:0];
        9'h5:
          r_sb_regs_rd <= fifo_data_out[63:32];
        9'h6:
          r_sb_regs_rd <= fifo_data_out[95:64]; // top 8 are a sequence count
        9'h7:
        begin
          r_sb_regs_rd <= {13'h00,
                           alignment_out, // 4
                           rx_data_ready, // 1
                           rx_data_raw, // 10
                           rx_dat_aligned, pll_locked, full, empty};  // don't look at full because it's async. We can embed a counter to check for drops.
          fifo_read_en <= 1'b1;
        end
        default:
          r_sb_regs_rd <= 32'h1badc0de; // Default case for addresses not defined
      endcase
    end
  end

  // mux registers and ram

  always @ (sb_addr[10] or r_sb_regs_rd or ila_logger_data)
  begin
    if (sb_addr[10])
    begin
      sb_data_rd_mux <= ila_logger_data;
    end
    else
    begin
      sb_data_rd_mux <= r_sb_regs_rd;
    end
  end
  assign sb_data_rd = sb_data_rd_mux;

  assign logger_data_in = {16'h0, alignment_out, rx_data_ready, rx_dat_aligned, rx_data_raw};


  ila_logger ila_logger_inst (
               .clk_fast(clk_200M),
               .valid(rx_data_ready),
               .data(logger_data_in),
               .clk(clk_52M),
               .we(sb_wea),
               .addr(sb_addr[10:2]),
               .ram_readback(ila_logger_data)
             );


endmodule
`default_nettype wire // turn it off
