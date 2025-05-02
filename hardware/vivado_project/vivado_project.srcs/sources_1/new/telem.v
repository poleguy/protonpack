`timescale 1ns / 1ps
`default_nettype none // do not use implicit wire for port connections

module telem
   #(
  //   parameter integer STREAM0_VAL_COUNT = 3815,
  //   parameter integer STREAM1_VAL_COUNT = 59,
  //   parameter integer STREAM2_VAL_COUNT = 238,
  //  parameter g_debug = 1, // boolean as integer 0 or 1
  //  parameter g_link_wait = 1 // boolean as integer 0 or 1
   parameter g_match_cnt = 19'h4ffff,
   parameter g_timeout_cnt = 16'hffff,
   parameter g_debug = 1
  )
  (
    //input push_rst,
    input wire clk_102M4,
    //input wire clk_256M,

    input wire serial_in_p,
    input wire serial_in_n,

    output wire okay_led_out,
    output wire rst_102M4
  );

  // More signals declaration similar to VHDL

  reg r_rst_self_102M4_n = 0;
  reg [4:0] r_rst_self_cnt_102M4 = 0;
  wire okay_led;
  wire cnt_led_out;
  wire [87:0] data_out;
  wire valid_out;
  wire pll_locked;
  wire clk_256M;




  always @(posedge clk_102M4)
  begin
    // Check if reset counter has reached its max value
    if (r_rst_self_cnt_102M4 == 5'b11111)
    begin
      r_rst_self_102M4_n <= 1'b1;
    end
    else
    begin
      r_rst_self_cnt_102M4 <= r_rst_self_cnt_102M4 + 5'b00001;
    end
  end

  assign rst_102M4 = ~r_rst_self_102M4_n;

  assign okay_led_out = okay_led;


  //-- xapp523 based receiver

  //-- ---------------------------------------------------------------------------------------------
  //---- LVDS Receiver
  //-----------------------------------------------------------------------------------------------


  //   IBUFDS_DIFF_OUT_SERIAL_IN_inst : IBUFDS_DIFF_OUT
  //     port map (
  //       O  => SERIAL_IN_BUF_P,
  //       OB  => SERIAL_IN_BUF_N,
  //       I  => SERIAL_IN_P,
  //       IB => SERIAL_IN_N
  //       );


  check_telemetry #(
                    .g_debug(g_debug),
                    .g_match_cnt(g_match_cnt),
                    .g_timeout_cnt(g_timeout_cnt)
                  ) check_telemetry_1 (
                    .clk_102M4(clk_102M4),
                    .rst_102M4(rst_102M4),
                    .clk_256M_out(clk_256M),
                    .pll_locked_out(pll_locked),
                    .serial_in_n(serial_in_n),
                    .serial_in_p(serial_in_p),
                    .okay_led_out(okay_led), // Internal 256 MHz clock domain
                    .cnt_led_out(cnt_led_out), // Internal 256 MHz clock domain
                    .data_out(data_out), // Internal 256 MHz clock domain
                    .valid_out(valid_out) // Internal 256 MHz clock domain
                  );



endmodule
`default_nettype wire // turn it off
