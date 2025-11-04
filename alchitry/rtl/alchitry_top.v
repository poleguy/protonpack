`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
module alchitry_top (
    input wire clk,
    input wire rst_n,
    output wire [7:0] led,
    input wire usb_rx,
    output wire usb_tx,
    input wire ft_clk,
    input wire ft_rxf,
    input wire ft_txe,
    inout wire [15:0] ft_data,
    inout wire [1:0] ft_be,
    output wire ft_rd,
    output wire ft_wr,
    output wire ft_oe,
    output wire ft_wakeup,
    output wire ft_reset,
    input wire RXN_I,
    input wire RXP_I,
    input wire [0:0] GTREFCLK1P_I,
    input wire [0:0] GTREFCLK1N_I,
    output wire REC_CLOCK_P,
    output wire REC_CLOCK_N,
    output wire B29,
    output wire B27
  );
  wire rst;
  wire clk_wiz_reset;
  localparam _MP_STAGES_1420874663 = 3'h4;
  wire M_reset_cond_in;
  wire M_reset_cond_out;
  wire clk_100M; // to rename it
  wire clk_128M;
  wire clk_wiz_locked;
  reg r_clk_wiz_locked_128M = 1'b0;
  reg r1_clk_wiz_locked_128M = 1'b0;
//   reg r_clk_wiz_locked_256M = 1'b0;
//   reg r1_clk_wiz_locked_256M = 1'b0;
  reg r_rst_128M = 1'b0;
  reg r_rst_256M = 1'b0;
  wire clk_256M;
  wire [31:0] gt_data;
  wire [3:0] gt_data_is_k;
  wire [87:0] packet_data;
  wire packet_valid;
  // wire stream_clk0;
  // wire stream_valid0;
  // wire [31:0] stream_enable0;
  // wire [87:0] stream_data0;
  wire gt_clk;
  reg reset_counters = 0;
  wire [31:0] total_packets;
  wire [31:0] mismatch_packets;
  wire okay_led;
  wire link_count_okay;
  wire gt_soft_reset;
  //wire [47:0] tx_mac_dest;
  parameter FREQ_CNT_VAL = 16'h0800;

  localparam _MP_BUS_WIDTH_528252186 = 5'h10;
  localparam _MP_TX_BUFFER_528252186 = 12'h800;
  localparam _MP_RX_BUFFER_528252186 = 12'h800;
  localparam _MP_PRIORITY_528252186 = 16'h5258;
  localparam _MP_PREEMPT_528252186 = 1'h0;
  wire M_ft_ft_rxf;
  wire M_ft_ft_txe;
  wire M_ft_ft_rd;
  wire M_ft_ft_wr;
  wire M_ft_ft_oe;

  wire [15:0] M_ft_ui_din;
  wire [1:0] M_ft_ui_din_be;
  wire M_ft_ui_din_valid;
  /* verilator lint_off UNOPTFLAT */
  wire M_ft_ui_din_full;

  wire [15:0] M_ft_ui_dout;
  wire [1:0] M_ft_ui_dout_be;
  wire M_ft_ui_dout_empty;
  wire M_ft_ui_dout_get;
  wire blinky_led;
//  wire blinky_led_100M;
  wire blinky_led_ft;

  reg [15:0] r_serial_in;
  reg r_serial_in_valid;

  reg [3:0] r_cnt = 4'hf;
  reg [15:0] r_packet_cnt = 16'h0;
  reg r_packet_valid;
  reg r1_packet_valid;
  reg r_packet_valid_128;

  initial begin
    //$dumpfile();                // default "dump.vcd"
    $dumpfile("wave1.fst");     // dumps into "wave1.gst"
  end

  initial begin
    $dumpvars (0);        // Dumps all variables from all module instances

  end
  reset_conditioner #(.STAGES(_MP_STAGES_1420874663)) reset_cond(
                      .clk(clk_128M),
                      .in(M_reset_cond_in),
                      .out(M_reset_cond_out)
                    );
  ft #(
       .BUS_WIDTH(_MP_BUS_WIDTH_528252186),
       .TX_BUFFER(_MP_TX_BUFFER_528252186),
       .RX_BUFFER(_MP_RX_BUFFER_528252186),
       .PRIORITY(_MP_PRIORITY_528252186),
       .PREEMPT(_MP_PREEMPT_528252186)
     ) ft(
       .ft_clk(ft_clk),
       .ft_data(ft_data),
       .ft_be(ft_be),
       .clk(clk_128M),
       .rst(rst),
       .ft_rxf(M_ft_ft_rxf),
       .ft_txe(M_ft_ft_txe),
       .ft_rd(M_ft_ft_rd),
       .ft_wr(M_ft_ft_wr),
       .ft_oe(M_ft_ft_oe),
       .ui_din(M_ft_ui_din),
       .ui_din_be(M_ft_ui_din_be),
       .ui_din_valid(M_ft_ui_din_valid),
       .ui_din_full(M_ft_ui_din_full),
       .ui_dout(M_ft_ui_dout),
       .ui_dout_be(M_ft_ui_dout_be),
       .ui_dout_empty(M_ft_ui_dout_empty),
       .ui_dout_get(M_ft_ui_dout_get)
     );

  /* verilator lint_on UNOPTFLAT */

  //always @(*) begin
  assign M_reset_cond_in = !rst_n;
  assign rst = M_reset_cond_out;
  assign led = {blinky_led,blinky_led_ft, 1'b0,clk_wiz_locked,ft_txe, ft_rxf, M_ft_ui_dout_empty, M_ft_ui_din_full};
  assign usb_tx = usb_rx;
  assign M_ft_ft_rxf = ft_rxf;
  assign M_ft_ft_txe = ft_txe;
  assign ft_rd = M_ft_ft_rd;
  assign ft_wr = M_ft_ft_wr;
  assign ft_oe = M_ft_ft_oe;
  assign ft_wakeup = 1'h1;
  assign ft_reset = !rst;
  assign M_ft_ui_dout_get = !M_ft_ui_din_full;
  //assign M_ft_ui_din_valid = !M_ft_ui_dout_empty;

  //assign M_ft_ui_din = M_ft_ui_dout;

  //assign M_ft_ui_din_be = M_ft_ui_dout_be;
  assign clk_wiz_reset = !rst_n;

  assign clk_100M = clk;

  clk_wiz_100M clk_wiz_100M_i(
                 .clk_in1(clk_100M),
                 .reset(clk_wiz_reset),
                 .clk_out1(clk_128M),
                 .locked(clk_wiz_locked)
               );

  always @(posedge clk_128M) begin
    r_clk_wiz_locked_128M <= clk_wiz_locked;
    r1_clk_wiz_locked_128M <= r_clk_wiz_locked_128M;
    if (r1_clk_wiz_locked_128M == 0)
      r_rst_128M <= 1;
    else
      r_rst_128M <= 0;
  end
//   always @(posedge clk_256M) begin
//     r_clk_wiz_locked_256M <= clk_wiz_locked;
//     r1_clk_wiz_locked_256M <= r_clk_wiz_locked_256M;
//     if (r1_clk_wiz_locked_256M == 0)
//       r_rst_256M <= 1;
//     else
//       r_rst_256M <= 0;
//   end

  //   BUFG bufg_clk(
  //          .O(clk_100M),
  //          .I(clk)
  //        );
  //   OBUFDS #(
  //            .IOSTANDARD("DEFAULT"),
  //            .SLEW("FAST")
  //          ) OBUFDS_REC_CLOCK(
  //            .O(REC_CLOCK_P),
  //            .OB(REC_CLOCK_N),
  //            .I(clk_128M)
  //          );

  // it seems this stupid board doesn't have any non 3.3V banks. ugh.
  // try to fake differential for the clock:

  assign REC_CLOCK_P = clk_128M;
  assign REC_CLOCK_N = ~clk_128M;

  gt_serial_telem_rx_subsystem gt_serial_telem_rx_subsystem(
                                 .Q0_CLK1_GTREFCLK_PAD_N_IN(GTREFCLK1N_I[0]),
                                 .Q0_CLK1_GTREFCLK_PAD_P_IN(GTREFCLK1P_I[0]),
                                 .DRP_CLK_IN(clk_128M),
                                 .RST_128M(r_rst_128M),
                                 .SOFT_RESET_OUT(gt_soft_reset),
                                 .RXN_IN(RXN_I),
                                 .RXP_IN(RXP_I),
                                 .TXN_OUT(),
                                 .TXP_OUT(),
                                 .DATA_CLK_OUT(gt_clk), //RXUSRCLK2
                                 .DATA_OUT(gt_data),
                                 .DATA_IS_K_OUT(gt_data_is_k)
                               );
  gt_unpack_telemetry gt_unpack_telemetry(
                        .clk_128M(clk_128M),
                        .rst_128M(r_rst_128M),
                        .gt_clk(gt_clk),
                        .gt_data(gt_data),
                        .gt_data_is_k(gt_data_is_k),
                        .clk_256M_out(clk_256M),
                        .pll_locked_out(),
                        .okay_led_out(),
                        .cnt_led_out(),
                        .data_out(packet_data),
                        .valid_out(packet_valid)
                      );
  telemetry_check telemetry_check(
                    .clk_256M(clk_256M),
                    .packet_data(packet_data),
                    .packet_valid(packet_valid),
                    .reset_counters(reset_counters),
                    .total_packets(total_packets),
                    .mismatch_packets(mismatch_packets),
                    .okay_led(okay_led),
                    .link_count_okay(link_count_okay)
                  );

  blink_led blink_led(
              .clk_128M(clk_128M),
              .led(blinky_led)
            );

  blink_led blink_led_ft(
              .clk_128M(ft_clk),
              .led(blinky_led_ft)
            );


  assign B29 = gt_clk;
  assign B27 = gt_data_is_k;
  //  blink_led blink_led_100M(
  //              .clk_128M(clk_100M),
  //              .led(blinky_led_100M)
  //            );


  // drive the serial data out of the FT interface for debug:

  always @(posedge clk_128M) begin
    if (r_cnt == 4'h0) begin
      r_serial_in <= packet_data[15:0];
      r_serial_in_valid <= 1'b1;
    end
    else if (r_cnt == 4'h1) begin
      r_serial_in <= packet_data[31:16];
    end
    else if (r_cnt == 4'h2) begin
      r_serial_in <= packet_data[47:32];
    end
    else if (r_cnt == 4'h3) begin
      r_serial_in <= packet_data[63:48];
    end
    else if (r_cnt == 4'h4) begin
      r_serial_in <= packet_data[79:64];
    end
    else if (r_cnt == 4'h5) begin
      // insert "|" character to make it easier to debug.
      r_serial_in <= {8'h7C, packet_data[87:80]};
    end
    else if (r_cnt == 4'h6) begin        
       // extra magic word for debug: "CODE"
      r_serial_in <= {16'hDEC0};
    end
    else if (r_cnt == 4'h7) begin      
      r_serial_in <= r_packet_cnt;
    end
    else begin
      // send k character when idle (default)
      r_serial_in <= 8'hBC;
      r_serial_in_valid <= 1'b0;
    end
  end


  // count bytes
  always @(posedge clk_128M) begin
    if (r_packet_valid_128) begin
      // start count
      r_cnt <= 4'h0;
    end
    else if (r_cnt > 4'h7) begin
      // stop counting when all bytes are sent and wait for next valid_in
      r_cnt <= 4'h8;
    end
    else begin
      // count for each byte of data
      r_cnt <= r_cnt + 4'h1;
    end

  end


    // count packets to see if FT600 is dropping words.
  always @(posedge clk_128M) begin
    if (r_packet_valid_128) begin
      r_packet_cnt <= r_packet_cnt + 16'h1;
    end

  end


  //stretch into 128MHz clock domain

  always @(posedge clk_256M) begin
    if (packet_valid) begin
      r_packet_valid <= 1'b1;
    end
    else begin
      r_packet_valid <= 1'b0;
    end
    r1_packet_valid <= r_packet_valid;

    r_packet_valid_128 <= r_packet_valid || r1_packet_valid;
  end


  assign M_ft_ui_din = r_serial_in;

  assign M_ft_ui_din_be = 2'b11;
  assign M_ft_ui_din_valid = r_serial_in_valid;

  wire _unused_ok = 1'b0 && &{1'b0,
                              r_rst_256M,
                              // stream_clk0,
                              // stream_valid0,
                              // stream_enable0,
                              // stream_data0,
                              mismatch_packets,
                              okay_led,
                              total_packets,
                              link_count_okay,
                              gt_soft_reset,
                              FREQ_CNT_VAL,
                              1'b0};

endmodule

`resetall
