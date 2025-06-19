//-----------------------------------------------
// telemetry_serialize.v
//------------------------------------------------
//
// Copyright © 2022 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
//------------------------------------------------
// generate portable serial data stream
// accepts packets and packs them into a stream
//------------------------------------------------
// see version control for rev info
//------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module telemetry_serialize
  #(
     parameter g_debug = 1'b0)
   //    g_debug     : std_logic             := '1' // include ila
   (
     input wire        clk,
     input wire        clk4x,
     input wire        reset_clk,
     input wire [87:0] packet,
     input wire        packet_valid,
     output wire       serializer_ready,
     output wire       O,
     output wire       OB);



  //################################################
  // internals
  //################################################

  // pack
  wire              busy;

  // enc
  wire              k_enc_in;
  wire [7:0]        data_enc_in;
  wire              valid_enc_in;
  wire              rdisp_enc;

  // buffer
  reg               r_valid_buffer_in  = 1'b0;
  wire [9:0]        data_10bit;
  wire [7:0]        data_8bit;

  pack_10x_11byte pack_10x_11byte
                  (
                    .clk       ( clk),
                    .data_in   ( packet),
                    .valid_in  ( packet_valid),
                    .k_out     ( k_enc_in),
                    .data_out  ( data_enc_in),
                    .valid_out ( valid_enc_in),
                    .busy      ( busy)
                  );

  enc_8b10b enc_8b10b
            (
              .clk         ( clk),
              .datain_8b   ( data_enc_in),
              .kin         ( k_enc_in),
              .en          ( valid_enc_in),
              .rdispin     ( rdisp_enc),
              .dataout_10b ( data_10bit),
              .k_err       (),
              .rdispout    ( rdisp_enc)
            );


  // delay valid to align with 8b10b output
  always @(posedge clk)
  begin
    r_valid_buffer_in <= valid_enc_in;
  end

  // take 10bit inputs at 8 out of 10 clocks
  // output 8 bit outputs on every clock
  buffer_10bit_to_8bit buffer_10bit_to_8bit
                       (
                         .clk      ( clk),
                         .valid       ( r_valid_buffer_in),
                         .data_in  ( data_10bit),
                         .data_out ( data_8bit));

  // 8x, high speed serial output
  oserdes8x oserdes8x
            (
              .clk    ( clk),
              .clk_4x ( clk4x),
              .reset_clkdiv  ( reset_clk),
              .data   ( data_8bit),
              .O      ( O),
              .OB     ( OB));

  // drive output
  assign serializer_ready = ~busy;

endmodule
`resetall
