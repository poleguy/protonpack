// checks for a counter in stream 13 (0xD)
// for use with telemetry_test_counter.v

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module telemetry_check #(
  parameter [19:0] g_match_cnt = 20'h4ffff, // turn on led after data is good for this number of valid periods
                                            // valid period of 1.6 usec means 500msec is about 4ffff
  parameter [15:0] g_timeout_cnt = 16'hffff // timeout to turn off led if no valids are seen for a short period
)(
  input wire clk_256M,
  input wire [87:0] packet_data,
  input wire packet_valid,
  // reset the packet counters
  input wire reset_counters,
  output wire [31:0] total_packets,
  // note, 
  // a single dropped count value will show up as 1 mismatch
  // a single errored count value will show up as 2 mismatches and won't show up in the total_packets count
  // no check of the expected rate is being done.
  output wire [31:0] mismatch_packets,

        
  output wire okay_led,  // once link is good for a long streak, this turns on and stays on
                        // until there is an error. This helps see that
                        // the link has no errors because it will
                        // obviously blink off if there is even a single error.
  output wire link_count_okay // this tracks errors rapidly and must be
                             // looked at with a scope to see errors.
                             // This will help if the link is popping
                             // lots of errors to see that it's sorta working.
);

  reg [31:0] r_total_packets = 0;
  reg [31:0] r_mismatch_packets = 0;
  
  reg [9:0] r_data_expected = 0;

  // unpack
  wire valid_unpack_out;
  wire [87:0] data_unpack_out;

  // check
  reg r_data_match = 0;
  reg [15:0] r_timeout_cnt = 0;
  reg [19:0] r_match_cnt = 0;

  reg r_okay_led_out = 0;
  reg r_link_count_okay = 0;

  assign data_unpack_out = packet_data;
  assign valid_unpack_out = packet_valid;

  // grab the last data and increment it, to check next data
  // only checking class_id = E for now
  // only checking count
  always @(posedge clk_256M) begin
    if (valid_unpack_out) begin
      if (data_unpack_out[83:80] == 4'hD) begin
        // counter is only for the lower 10 bits, and wraps
        r_data_expected <= data_unpack_out[9:0] + 1;
      end
    end
  end

  // check result
  // and calculate statistics
  // statistics do not automatically reset, so we won't miss any trouble during testing
  always @(posedge clk_256M) begin
    if (reset_counters) begin
      r_total_packets <= 0;
      r_mismatch_packets <= 0;
    end else if (valid_unpack_out) begin
      r_total_packets <= r_total_packets + 1;  // Increment total packets count
      if (data_unpack_out[83:80] == 4'hD) begin
        if (data_unpack_out[9:0] == r_data_expected) begin
          // data arriving matches expected data
          r_data_match <= 1;
        end else begin
          r_data_match <= 0;
          r_mismatch_packets <= r_mismatch_packets + 1;  // Increment mismatch packets count
        end
      end
    end
  end

  // generate led that goes on if data is good for > 500 msec, and goes out
  // immediately on error
  // also one that goes on and off immediately
  always @(posedge clk_256M) begin
    if (valid_unpack_out) begin
      r_timeout_cnt <= 0;
      if (r_data_match) begin
        // valid period of 1.6 usec means 500msec is about 4ffff
        r_link_count_okay <= 1;
        if (r_match_cnt >= g_match_cnt) begin
          r_okay_led_out <= 1;
        end else begin
          r_match_cnt <= r_match_cnt + 1;
        end
      end else begin
        r_link_count_okay <= 0;
        r_okay_led_out <= 0;
        r_match_cnt <= 0;
      end
    end else begin
      // timeout if no valids seen in a bit
      if (r_timeout_cnt == g_timeout_cnt) begin
        r_link_count_okay <= 0;
        r_okay_led_out <= 0;
      end
      r_timeout_cnt <= r_timeout_cnt + 1;
    end
  end

  // outputs
  assign okay_led = r_okay_led_out;
  assign link_count_okay = r_link_count_okay;  
  assign total_packets = r_total_packets;
  assign mismatch_packets = r_mismatch_packets;

endmodule

`resetall
