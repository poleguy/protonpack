//--------------------------------------------------
// oserdes8x.v
//--------------------------------------------------
//
// Copyright © 2021 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
//--------------------------------------------------
// provide 128 MHz and 512 MHz clocks
// and 8 bits of data per 128 MHz clock
// send out 1024 Mbit data stream
//
//--------------------------------------------------
// see version control for rev info
//--------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module oserdes8x (
    input wire clk,
    input wire clk_4x,
    input wire reset_clkdiv, // active high
    input wire [7:0] data,   // 8 bits of input data
    output wire O,           // pin output
    output wire OB           // pin output
  );

  wire OQ;

  // OSERDESE2: Output SERial/DESerializer with bitslip
  // 7 Series
  // Xilinx HDL Libraries Guide, version 2012.2

  OSERDESE2 #(
              .DATA_RATE_OQ("DDR"),    // DDR, SDR
              .DATA_RATE_TQ("SDR"),    // DDR, BUF, SDR
              .DATA_WIDTH(8),          // Parallel data width (2-8, 10, 14)
              .INIT_OQ(1'b0),          // Initial value of OQ output (1'b0, 1'b1)
              .INIT_TQ(1'b0),          // Initial value of TQ output (1'b0, 1'b1)
              .SERDES_MODE("MASTER"),  // MASTER, SLAVE
              .SRVAL_OQ(1'b0),         // OQ output value when SR is used (1'b0, 1'b1)
              .SRVAL_TQ(1'b0),         // TQ output value when SR is used (1'b0, 1'b1)
              .TBYTE_CTL("FALSE"),     // Enable tristate byte operation (FALSE, TRUE)
              .TBYTE_SRC("FALSE"),     // Tristate byte source (FALSE, TRUE)
              .TRISTATE_WIDTH(1)       // 3-state converter width (1,4)
            ) OSERDESE2_inst (
              .OFB(),                  // 1-bit output: Feedback path for data
              .OQ(OQ),                 // 1-bit output: Data path output
              // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
              .SHIFTOUT1(),
              .SHIFTOUT2(),
              .TBYTEOUT(),             // 1-bit output: Byte group tristate
              .TFB(),                  // 1-bit output: 3-state control
              .TQ(),                   // 1-bit output: 3-state control
              .CLK(clk_4x),            // 1-bit input: High speed clock
              .CLKDIV(clk),            // 1-bit input: Divided clock
              // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
              .D1(data[0]),
              .D2(data[1]),
              .D3(data[2]),
              .D4(data[3]),
              .D5(data[4]),
              .D6(data[5]),
              .D7(data[6]),
              .D8(data[7]),
              .OCE(1'b1),              // 1-bit input: Output data clock enable
              .RST(reset_clkdiv),      // 1-bit input: Reset
              // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
              .SHIFTIN1(1'b0),
              .SHIFTIN2(1'b0),
              // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
              .T1(1'b0),
              .T2(1'b0),
              .T3(1'b0),
              .T4(1'b0),
              .TBYTEIN(1'b0),          // 1-bit input: Byte group tristate
              .TCE(1'b0)               // 1-bit input: 3-state clock enable
            );

  // OBUFDS: Differential Output Buffer
  // 7 Series
  // Xilinx HDL Libraries Guide, version 2012.2
  OBUFDS #(
           .IOSTANDARD("LVDS"),     // Specify the output I/O standard
           .SLEW("FAST")            // Specify the output slew rate
         ) OBUFDS_inst (
           .O(O),                   // Diff_p output (connect directly to top-level port)
           .OB(OB),                 // Diff_n output (connect directly to top-level port)
           .I(OQ)                   // Buffer input
         );

endmodule
`resetall


