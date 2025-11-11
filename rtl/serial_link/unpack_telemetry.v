//-------------------------------------------------
// unpack_telemetry.v
//-------------------------------------------------
//
// Copyright © 2019 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
//-------------------------------------------------
// this will only decode data if it sees a valid k character before the data
// unpacks a series of bytes from the 8b10b decoder
// converts it into a 11 byte wide output and valid
//-------------------------------------------------
// see version control for rev info
//-------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module unpack_telemetry #(
    parameter g_data_width = 11 // effectively a constant, in bytes (only 11 is supported)
  )(
    input wire clk,
    input wire k_in,
    input wire [7:0] data_in,
    input wire valid_in,
    output reg [(g_data_width*8)-1:0] data_out,
    output reg valid_out,
    output wire bad_packet
  );

  reg [7:0] r_data_in = 8'b0;
  reg [(g_data_width*8)-1:0] r_data_out = { (g_data_width*8) {1'b0} };
  reg r_valid_out = 1'b0;
  // handles up to 15 data words, default to a stopped state to avoid a false start after reset
  // start at 0xE, which indicates a k character hasn't been seen yet, so we shouldn't start.
  // 0xE also can mean too many bytes were seen, which indicates an error, so don't start until a k character is seen
  reg [3:0] r_cnt = 4'he; 
  reg r_bad_packet = 1'b0;

  // Ensure only 11 byte telemetry data is supported
  initial begin
    if (g_data_width != 11)
      $fatal("Only 11 byte telemetry data is supported");
  end

  always @(posedge clk) begin
    if (valid_in == 1) begin
      // ignore k character when idle
      // stream byte (1) is ignored, as it will be hard coded to zero
      case (r_cnt)
        4'h0: begin
          r_data_out[7:0] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h1: begin
          r_data_out[15:8] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h2: begin
          r_data_out[23:16] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h3: begin
          r_data_out[31:24] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h4: begin
          r_data_out[39:32] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h5: begin
          r_data_out[8*6-1:40] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h6: begin
          r_data_out[8*7-1:8*6] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h7: begin
          r_data_out[8*8-1:8*7] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h8: begin
          r_data_out[8*9-1:8*8] <= r_data_in;
          r_valid_out <= 0;
        end
        4'h9: begin
          r_data_out[8*10-1:8*9] <= r_data_in;
          r_valid_out <= 0;
        end
        4'ha: begin
          r_data_out[8*11-1:8*10] <= r_data_in;
          // only send out valid data once all has been received
          r_valid_out <= 1;
        end
        default:
          r_valid_out <= 0;
      endcase
    end
    else begin
      r_valid_out <= 0;
    end
  end

  always @(posedge clk) begin
    if (valid_in == 1) begin
      if (k_in == 0) begin
        r_data_in <= data_in;
      end
    end
  end

  // count bytes while not k_in is low
  // can only handle length of 14, which is fine because this is hard coded for 11 byte packets
  always @(posedge clk) begin    
    if (valid_in == 1) begin
      if (k_in == 0) begin
        // count bytes
        if (r_cnt == 4'he) begin
          // don't wrap as this could cause a stuck packet repeatedly sent at
          // the output if the link fails/stops.
          r_cnt <= 4'he;
        end
        else begin
          r_cnt <= r_cnt + 1'b1;
        end
        r_bad_packet <= 1'b0;
      end
      else begin
        // this will wrap on the next data byte (i.e. k_in = '0')
        r_cnt <= 4'hf;
        if (! ((r_cnt == 4'ha) || (r_cnt == 4'hf))) begin
            // too short? should be 11 bytes
            r_bad_packet <= 1'b1;
        end
      end
    end
  end
  assign bad_packet = r_bad_packet;

  // outputs
  always @(posedge clk) begin
    data_out <= r_data_out;
    valid_out <= r_valid_out;
  end

endmodule
`resetall
