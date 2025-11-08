`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module pack_10x_11byte (
    input wire clk,
    input wire valid_in,         // must not drive valid_in when busy
    input wire [87:0] data_in,   // packs input data one byte at a time into output data
    output wire k_out,            // fills all idle time with k characters
    output wire [7:0] data_out,   // spits out a data byte 8 out of every 10 clocks to allow space for 8b/10b coding
    output wire valid_out,
    output wire busy              // '0' when ready for another valid_in
  );

  // Internal signals
  reg [87:0] r_data_in = 88'b0;
  reg [7:0] r_data_out = 8'b0;
  reg r_k_out = 1'b0;
  reg r_busy = 1'b0;
  reg r_valid_out = 1'b0;
  reg r1_valid_out = 1'b0;
  // handles up to 15 data words, default to a stopped state to avoid sending a packet at start until valid_in
  reg [3:0] r_cnt = 4'hf;
  reg [3:0] r_skip_cnt = 4'b0000; // count 0 to 9 forever

  always @(posedge clk)
  begin
    if (r_cnt == 4'h0)
    begin
      r_data_out <= r_data_in[7:0];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h1)
    begin
      r_data_out <= r_data_in[15:8];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h2)
    begin
      r_data_out <= r_data_in[23:16];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h3)
    begin
      r_data_out <= r_data_in[31:24];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h4)
    begin
      r_data_out <= r_data_in[39:32];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h5)
    begin
      r_data_out <= r_data_in[47:40];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h6)
    begin
      r_data_out <= r_data_in[55:48];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h7)
    begin
      r_data_out <= r_data_in[63:56];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h8)
    begin
      r_data_out <= r_data_in[71:64];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'h9)
    begin
      r_data_out <= r_data_in[79:72];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else if (r_cnt == 4'ha)
    begin
      r_data_out <= r_data_in[87:80];
      r_k_out <= 1'b0;
      r_busy <= 1'b1;
    end
    else
    begin
      // send k character when idle (default)
      r_k_out <= 1'b1;
      r_data_out <= 8'hBC;
      r_busy <= 1'b0;
    end
  end

  // count bytes
  always @(posedge clk)
  begin
    if (valid_in)
    begin
      // start count
      r_cnt <= 4'h0;
    end
    else if (r_cnt > 4'ha)
    begin
      // stop counting when all bytes are sent and wait for next valid_in
      r_cnt <= 4'hb;
    end
    else if (r_skip_cnt < 4'h8)
    begin
      // count when output data is needed (8 out of 10 clocks for 8b10b)
      r_cnt <= r_cnt + 4'h1;
    end
  end

  // count to skip 2 out of 10
  // to produce 8 outputs for every 10 inputs (for 8b10b)
  always @(posedge clk)
  begin
    if (r_skip_cnt == 4'h9)
    begin
      r_skip_cnt <= 4'h0;
      r_valid_out <= 1'b1;
    end
    else if (r_skip_cnt < 4'h7)
    begin
      r_skip_cnt <= r_skip_cnt + 4'h1;
      r_valid_out <= 1'b1;
    end
    else
    begin
      // count until we wrap
      r_skip_cnt <= r_skip_cnt + 4'h1;
      r_valid_out <= 1'b0;
    end
  end

  // register input
  always @(posedge clk)
  begin
    if (valid_in)
    begin
      r_data_in <= data_in;
    end
  end

  always @(posedge clk)
  begin
    r1_valid_out <= r_valid_out;
  end

  // outputs
  assign data_out = r_data_out;
  assign k_out = r_k_out;
  assign busy = r_busy;
  assign valid_out = r1_valid_out;

endmodule
`resetall

