
//-------------------------------------------------
// buffer_10bit_to_8bit.v
//-------------------------------------------------
//
// Copyright © 2019 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
//-------------------------------------------------
// encode 10bit data into serial stream
// 10 bits of data should arrive for eight out of every ten clocks
// 8 bits of output data is generated on every clock
//
//-------------------------------------------------
// see version control for rev info
//-------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections


module buffer_10bit_to_8bit (
    input wire clk,
    input wire valid,
    input wire [9:0] data_in,   // parallel input

    output reg [7:0] data_out   // byte output
  );

  reg [3:0] cnt_valid = 4'b0000;
  reg [3:0] cnt_output = 4'b0000;
  reg [23:0] r_data_shift = 24'b0;
  reg [7:0] r_byte = 8'b0;
  reg [7:0] r1_byte = 8'b0;
  reg [7:0] r2_byte = 8'b0;
  reg r_grab_input = 1'b0;
  reg r_valid = 1'b0;

  // count input words
  always @(posedge clk)
  begin
    if (valid == 1'b1)
    begin
      if (cnt_valid == 4'h7)
      begin
        cnt_valid <= 4'h0;
      end
      else
      begin
        cnt_valid <= cnt_valid + 1'b1;
      end
    end
  end

  always @(posedge clk)
  begin
    r_valid <= valid;
  end

  always @(posedge clk)
  begin
    r_data_shift[15:0] <= r_data_shift[23:8];
    if (r_valid == 1'b1)
    begin
      case (cnt_valid)
        4'h0:
          r_data_shift[9:0] <= data_in;
        4'h1:
          r_data_shift[11:2] <= data_in;
        4'h2:
          r_data_shift[13:4] <= data_in;
        4'h3:
          r_data_shift[15:6] <= data_in;
        4'h4:
          r_data_shift[17:8] <= data_in;
        4'h5:
          r_data_shift[19:10] <= data_in;
        4'h6:
          r_data_shift[21:12] <= data_in;
        4'h7:
          r_data_shift[23:14] <= data_in;
      endcase
    end
  end

  always @(posedge clk)
  begin
    r_byte <= r_data_shift[7:0];
  end

  // to help timing
  always @(posedge clk)
  begin
    r1_byte <= r_byte;
  end

  // to help timing
  always @(posedge clk)
  begin
    r2_byte <= r1_byte;
  end

  always @(posedge clk)
  begin
    data_out <= r2_byte;
  end

endmodule
`resetall


