`timescale 1ns/1ps

/*-------------------------------------------------------------------------------
-- Testbench for ESM serial interface testing
-- Tests the embedded system module CLI via UART
-------------------------------------------------------------------------------*/

module tb_esm_serial;

  // System clock and reset
  reg clk_100   = 1'b0;
  reg rst_n = 1'b0;

  // UART signals
  wire uart_tx;  // Output from DUT
  reg  uart_rx = 1'b1;  // Input to DUT (idle high)

  // FT interface (not used in this test, but required by DUT)
  reg         ft_clk = 1'b0;
  reg         ft_rxf = 1'b1;
  reg         ft_txe = 1'b1;
  wire [15:0] ft_data;
  wire [1:0]  ft_be;
  wire        ft_rd;
  wire        ft_wr;
  wire        ft_oe;
  wire        ft_wakeup;
  wire        ft_reset;

  // Transceiver inputs (not used, but required by DUT)
  reg        RXN_I = 1'b0;
  reg        RXP_I = 1'b0;
  reg [0:0]  GTREFCLK1P_I = 1'b0;
  reg [0:0]  GTREFCLK1N_I = 1'b0;

  // DUT outputs
  wire [7:0] led;
  wire REC_CLOCK_P;
  wire REC_CLOCK_N;

  // USB signals (not used)
  reg  usb_rx = 1'b0;
  wire usb_tx;

  // Button inputs (set to inactive)
  reg BOT_B3 = 1'b0;
  reg BOT_B5 = 1'b0;
  reg BOT_B4;  // This is UART_RX
  wire BOT_B6;  // This is UART_TX
  wire [7:0] BOT_C_L;

  // 100 MHz system clock
  initial begin
    forever begin
      #5.000 clk_100 = ~clk_100;  // 100 MHz (10ns period)
    end
  end

  // 100 MHz FT clock (required for FT module)
  initial begin
    forever begin
      #5.000 ft_clk = ~ft_clk;  // 100 MHz
    end
  end

  // Connect UART through BOT pins
  assign BOT_B4 = uart_rx;
  assign uart_tx = BOT_B6;

  // Reset initialization
  initial begin
    rst_n = 1'b0;
    #100 rst_n = 1'b1;
  end

  // Device Under Test
  alchitry_top alchitry_top (
    .clk(clk_100),
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
    .REC_CLOCK_N(REC_CLOCK_N),
    .BOT_B30(),
    .BOT_B28(),
    .BOT_B3(BOT_B3),
    .BOT_B5(BOT_B5),
    .BOT_B4(BOT_B4),
    .BOT_B6(BOT_B6),
    .BOT_C_L(BOT_C_L)
  );

  // Dump waveforms in FST format
  initial begin
    $dumpfile("esm_serial_test.fst");
    $dumpvars(0, tb_esm_serial);
    // Also dump the rs_core internals including progrom
    $dumpvars(0, alchitry_top.rs_core_0);
    $dumpvars(0, alchitry_top.rs_core_0.progrom);
  end

endmodule
