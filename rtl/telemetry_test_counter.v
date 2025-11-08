//////////////////////////////////////////////////
// 
//////////////////////////////////////////////////
//
// telemetry test counter
//
// A 10 bit counter with variable rate for bandwidth and link reliability testing
//
//////////////////////////////////////////////////
`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections


module telemetry_test_counter
  (input wire clk_128MHz,

   input wire [31:0] rate,

   output wire telemetry_trigger,
   input wire telemetry_request,
   output wire [31:0] telemetry_data,
   output wire telemetry_data_valid
  );

  reg [31:0] r_trigger_counter = 0; // count to a big number
  reg r_telemetry_trigger = 0;
  reg [31:0] r_telemetry_data = 0; 

  always @(posedge clk_128MHz) begin
    if (r_trigger_counter == rate) begin
      r_trigger_counter <= 0;
      r_telemetry_trigger <= 1'b1;
    end
    else begin
      r_trigger_counter <= r_trigger_counter + 1;
      r_telemetry_trigger <= 1'b0;
    end
  end


  reg [9:0] r_telemetry_test_counter = 0;
  reg r_telemetry_data_valid;

  always @(posedge clk_128MHz) begin
    if (r_telemetry_trigger == 1'b1) begin
      // count ten bits and wrap
      r_telemetry_test_counter[9:0] <= r_telemetry_test_counter + 1;
    end
  end


  assign telemetry_trigger = r_telemetry_trigger;

  always @(posedge clk_128MHz)
    r_telemetry_data_valid <= telemetry_request;

  always @(posedge clk_128MHz)
    r_telemetry_data <= r_telemetry_test_counter;

  assign telemetry_data_valid = r_telemetry_data_valid;
  assign telemetry_data = r_telemetry_data;

endmodule
`resetall
