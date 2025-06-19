`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
module enc_8b10b (
    input wire clk,
    input wire [7:0] datain_8b,      // 8-bit input data
    input wire kin,                  // K character input
    input wire rdispin,              // Running disparity input
    input wire en,                   // Enable signal
    output wire [9:0] dataout_10b,    // 10-bit encoded output data
    output wire k_err,                // K character error output
    output wire rdispout              // Running disparity output
  );

  // Internal signals
  reg [8:0] r_datain = 9'b0;
  wire [9:0] dataout;
  wire dispout;
  reg [9:0] r_dataout = 10'b0;
  reg r_dispout = 1'b0;
  reg r_en_1 = 1'b0;

  // Component encode (assumed to be implemented elsewhere)
  encode encode_1 (
           .datain(r_datain),
           .dispin(rdispin),
           .dataout(dataout),
           .dispout(dispout)
         );

  // Process to register enable signal
  always @(posedge clk)
  begin
    r_en_1 <= en;
  end

  // Process to register input data and K character
  always @(posedge clk)
  begin
    if (en)
    begin
      r_datain[7:0] <= datain_8b;
      r_datain[8] <= kin;
    end
  end

  // Process to register encoded output data and disparity
  always @(posedge clk)
  begin
    if (r_en_1)
    begin
      r_dispout <= dispout;
      r_dataout <= dataout;
    end
  end

  // Outputs
  assign dataout_10b = r_dataout;
  assign rdispout = r_dispout;
  assign k_err = 1'b0; // TODO: Detect errors.

endmodule
`resetall
