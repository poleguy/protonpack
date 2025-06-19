//--------------------------------------------------
// oserdes8x_dummy.v
//--------------------------------------------------
//
// Copyright 2025 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
//--------------------------------------------------
// does nothing for sim
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

  assign O = 1'b0;
  assign OB = 1'b1;

endmodule
`resetall


