//----------------------------------------------------------------------------
// 100MHz input 128MHz output
// dummy file to speed up simulation

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

/* verilator lint_off DECLFILENAME */
module mmcm 
 (
  // Clock out ports
  output  reg      clk_128M, // 128
  output  reg      clk_100M, // 100
  // Status and control signals
  output wire       locked,
  input wire reset,
 // Clock in ports
  input  wire       clk_in
 );


  reg [2:0] counter; // 3-bit counter to count up to 5 clocks
  reg r_locked;

  initial
  begin
    clk_128M = 0;
  end

  always
  begin
    #3.906 clk_128M = ~clk_128M;
  end

  always @(posedge clk_in)
  begin
    if (counter < 3'b101)
    begin // 5 in binary is '101'
      counter <= counter + 1;
    end
    else
    begin
      r_locked <= 1'b1; // Set locked high after 5 clock cycles
    end
  end

  assign clk_100M = clk_in;
  assign locked = r_locked;

endmodule
`resetall
