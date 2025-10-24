`timescale 1ns/1ps
`default_nettype none

module top_level_tb;

  // System clock and reset
  reg clk   = 1'b0;
  reg rst_n = 1'b0;

  // USB
  reg  usb_rx = 1'b0;
  wire usb_tx;

  // FT interface
  reg         ft_clk = 1'b0;
  reg         ft_rxf = 1'b1;
  reg         ft_txe = 1'b1;
  wire [15:0] ft_data;   // Inout from DUT; TB does not drive
  wire [1:0]  ft_be;     // Inout from DUT; TB does not drive
  wire        ft_rd;
  wire        ft_wr;
  wire        ft_oe;
  wire        ft_wakeup;
  wire        ft_reset;

  // Transceiver inputs (kept static for this basic TB)
  reg        RXN_I = 1'b0;
  reg        RXP_I = 1'b0;
  reg [0:0]  GTREFCLK1P_I = 1'b0;
  reg [0:0]  GTREFCLK1N_I = 1'b0;

  // DUT outputs
  wire [7:0] led;
  wire REC_CLOCK_P;
  wire REC_CLOCK_N;

  // Device Under Test
  alchitry_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .led(led),
    .usb_rx(usb_rx),
    .usb_tx(usb_tx),
    .ft_clk(ft_clk),
    .ft_rxf(ft_rxf),
    .ft_txe(ft_txe),
    .ft_data(ft_data),
    .ft_be(ft_be),
    .ft_rd(ft_rd),
    .ft_wr(ft_wr),
    .ft_oe(ft_oe),
    .ft_wakeup(ft_wakeup),
    .ft_reset(ft_reset),
    .RXN_I(RXN_I),
    .RXP_I(RXP_I),
    .GTREFCLK1P_I(GTREFCLK1P_I),
    .GTREFCLK1N_I(GTREFCLK1N_I),
    .REC_CLOCK_P(REC_CLOCK_P),
    .REC_CLOCK_N(REC_CLOCK_N)
  );

  // Generate system clock: 100 MHz (10 ns period)
  localparam real CLK_PERIOD_NS = 10.0;
  always #(CLK_PERIOD_NS/2.0) clk = ~clk;

  // Generate FT clock: 50 MHz (20 ns period)
  localparam real FT_CLK_PERIOD_NS = 20.0;
  always #(FT_CLK_PERIOD_NS/2.0) ft_clk = ~ft_clk;    

  // Basic stimulus
  initial begin
    // Apply reset
    rst_n = 1'b0;
    #(10*CLK_PERIOD_NS);
    rst_n = 1'b1;

  end

endmodule

`resetall
