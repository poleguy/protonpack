`timescale 1ns / 1ps
`default_nettype none // do not use implicit wire for port connections

//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04/21/2025 03:47:31 PM
// Design Name:
// Module Name: blink
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module blink(
    input wire clk,
    input wire inny,
    output reg outy,
    output wire reset_blink
  );

  // Parameters to calculate clock division factor
  // 100 MHz is 100,000,000 cycles per second, to get 1 second period we divide by 100,000,000
  parameter CLK_DIV = 100_000_000;
  // divide by five will turn a 100 MHz clock into a 10 MHz data output
  parameter CLK_DIV_10 = 5;

  reg [31:0] counter;  // 32-bit counter for clock division
  reg output_clock;  // 1 Hz signal generated
  reg r_reset_blink_n = 0;
  reg [4:0] r_rst_self_cnt = 0;

  // Clock divider process
  always @(posedge clk)
  begin
    if (inny && (counter >= CLK_DIV - 1))
    begin
      // if input is high, count slow
      counter <= 0;
      output_clock <= ~output_clock;
    end
    else if (~inny && (counter >= CLK_DIV_10 - 1))
    begin
      // in input is low, count fast
      counter <= 0;
      output_clock <= ~output_clock;
    end
    else
    begin
      counter <= counter + 1;
    end
  end

  // Send out fast clock based on state of input signal
  // This can be used with a frequency counter to check the clock speed
  always @(posedge clk)
  begin
    outy <= output_clock;
  end


  always @(posedge clk)
  begin
    // Check if reset counter has reached its max value
    if (r_rst_self_cnt == 5'b11111)
    begin
      r_reset_blink_n <= 1'b1;
    end
    else
    begin
      r_rst_self_cnt <= r_rst_self_cnt + 5'b00001;
    end
  end

  assign reset_blink = ~r_reset_blink_n;


endmodule
`default_nettype wire // turn it off
