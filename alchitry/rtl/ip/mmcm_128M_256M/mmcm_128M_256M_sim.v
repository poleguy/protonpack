//----------------------------------------------------------------------------
// User entered comments
//----------------------------------------------------------------------------
// None
//
//----------------------------------------------------------------------------
//  Output     Output      Phase    Duty Cycle   Pk-to-Pk     Phase
//   Clock     Freq (MHz)  (degrees)    (%)     Jitter (ps)  Error (ps)
//----------------------------------------------------------------------------
// clk_out1___128.000______0.000______50.0______116.993_____95.333
// clk_out2___256.000______0.000______50.0______102.686_____95.333
//
//----------------------------------------------------------------------------
// Input Clock   Freq (MHz)    Input Jitter (UI)
//----------------------------------------------------------------------------
// __primary_____________128____________0.010

// dummy file to speed up simulation

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
/* verilator lint_off DECLFILENAME */
module mmcm_128M_256M 
/* verilator lint_on DECLFILENAME */
 (// Clock in ports
  // Clock out ports
  output  wire      clk_out1,
  output  reg      clk_out2,
  // Status and control signals
  input   wire      reset,
  output  wire      locked,
  input  wire       clk_in1
 );

  reg [2:0] counter; // 3-bit counter to count up to 5 clocks
  reg r_locked;

  assign clk_out1 = clk_in1;

  initial
  begin
    clk_out2 = 0;
  end

  /* verilator lint_off BLKSEQ */
  always @(posedge clk_in1)
  begin
    clk_out2 = 1;
    #1.953 clk_out2 = 0;
  end
  /* verilator lint_on BLKSEQ */


  always @(posedge clk_in1)
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

  assign locked = r_locked;


  wire _unused_ok = 1'b0 && &{1'b0,
                    reset,
                    1'b0};
endmodule
`resetall


