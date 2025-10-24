`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

//-------------------------------------------------
// gt_unpack_telemetry.v
//--------------------------------------------------
//
// Copyright 2025 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
// expects byte aligned 32bit data
//
// pulls out the 11 byte payload and passes it along unmodified.
//
//--------------------------------------------------

module gt_unpack_telemetry #(
  //parameter G_DEBUG        = 1'b0,
  // turn on led after data is good for this number of valid periods
  // valid period of 1.6 usec means 500msec is about 4ffff
  parameter [19:0] G_MATCH_CNT   = 20'h4ffff,
  // timeout to turn off led if no valids are seen for a short period
  parameter [15:0] G_TIMEOUT_CNT = 16'hffff
)(
  input  wire        clk_128M,       // clock from gt
  input  wire        rst_128M,       // to reset pll
  // will be multiplied up to generate
  // 1024 mbit data stream
  // 512 MHz clock for DDR output
  // 256 MHz clock for data processing at 10bit or 8bit with valid
  // GT Transceiver input at 32MHz (treated async to clk_128M/clk_256M)
  input  wire        gt_clk,
  input  wire [31:0] gt_data,
  input  wire [3:0]  gt_data_is_k,
  output wire        clk_256M_out,
  output wire        pll_locked_out,
  output wire        okay_led_out,
  output wire        cnt_led_out,
  output wire [87:0] data_out,
  output wire        valid_out
);

  // attribute ASYNC_REG : string;
  wire clk_256M;

  reg [31:0] r_data_E = 32'h0000_0000;
  reg [31:0] r_data_F = 32'h0000_0000;

  // dec
  reg  [3:0]  r_valid      = 4'b0000;
  reg         r_valid_dec  = 1'b0;
  //  signal rdisp_dec    : std_logic;
  // signal k_dec_out    : std_logic;
  reg  [31:0] r_data       = 32'h0000_0000;
  reg  [3:0]  r_data_is_k  = 4'b0000;
  reg  [7:0]  r_data_dec   = 8'h00;
  reg         r_data_dec_k = 1'b0;

  // unpack
  wire        valid_unpack_out;
  wire [87:0] data_unpack_out;

  // check
  reg         r_data_match  = 1'b0;
  reg [15:0]  r_timeout_cnt = 16'h0000;
  reg [19:0]  r_match_cnt   = 20'h00000;

  reg         r_okay_led_out;

  wire        pll_locked;

  //  signal r_byte_cnt : unsigned(1 downto 0) := (others => '0');

  wire clk_128M_buf;

  
  (* ASYNC_REG = "TRUE" *) reg r_gt_clk        = 1'b0;
  (* ASYNC_REG = "TRUE" *) reg r1_gt_clk       = 1'b0;
                           reg r2_gt_clk       = 1'b0;
                           reg [31:0] r_gt_data       = 32'h0000_0000;
                           reg [3:0]  r_gt_data_is_k  = 4'b0000;
                           reg        r_gt_data_valid = 1'b0;


  mmcm_128M_256M mmcm_128M_256M_1 (
    .clk_in1  (clk_128M),
    .clk_out1 (clk_128M_buf),
    .clk_out2 (clk_256M),
    .reset    (rst_128M),
    .locked   (pll_locked)
  );

  //pll_locked <= '1';

  // expecting 50% ones if the data is good.
  // so we will get an average of 5 ones every valid
  // each valid comes at 102.4 Mhz
  // so 2**28 bits should give a 1/2 second toggle
  //  cnt_led_out <= r_cnt(27);
  assign cnt_led_out = 1'b0;

  //---------------------------------------------------------------------------------------------

  // note, clkout0 from the clock recovery is driving gt_data and gt_data_is_k
  // at 25.6 MHz... it's not clear why it wasn't being timed in 2018.2
  // but now in 2025.1 it is being timed and failing timing.
  // but we are treating it asynchronously, so it is added as an async clock
  // group. Be careful therefore to treat all the signals asynchronously.

  // reclock in to 256M domain
  // because 128M domain is asynchronous and might not be fast enough
  // proc_reclock : process(clk_256M)

  always @(posedge clk_256M) begin
    r_gt_clk  <= gt_clk;
    r1_gt_clk <= r_gt_clk;
    r2_gt_clk <= r1_gt_clk;

    // rising edge of slow clock
    if (r2_gt_clk == 1'b0 && r1_gt_clk == 1'b1) begin
      r_gt_data       <= gt_data;
      r_gt_data_is_k  <= gt_data_is_k;
      r_gt_data_valid <= 1'b1;
    end else begin
      r_gt_data_valid <= 1'b0;
    end
  end

  //  cycle through the 4 bytes of input data

  // count rising edges in input stream
  //  proc_byte_cnt: process(clk_128M_buf)

  // we get 4 bytes at a time
  // we need to stream them out one at a time with valids
  // the low byte is the oldest data and should be processed first.
  // proc_buffer_data : process(clk_256M)

  always @(posedge clk_256M) begin
    if (r_gt_data_valid == 1'b1 && pll_locked == 1'b1) begin
      r_valid     <= 4'b1111;
      r_data      <= r_gt_data[31:0];
      r_data_is_k <= r_gt_data_is_k[3:0];
    end else begin
      r_valid     <= {1'b0, r_valid[3:1]};
      r_data      <= {8'h00, r_data[31:8]};
      r_data_is_k <= {1'b0, r_data_is_k[3:1]};
    end
  end

  // proc_grab_byte : process(clk_256M)

  always @(posedge clk_256M) begin
    if (r_valid[0] == 1'b1) begin
      r_valid_dec  <= 1'b1;
      r_data_dec   <= r_data[7:0];
      r_data_dec_k <= r_data_is_k[0];
    end else begin
      r_valid_dec  <= 1'b0;
      r_data_dec   <= 8'h00;
      r_data_dec_k <= 1'b0;
    end
  end

  // this will only decode data if it sees a valid k character before the data
  // unpack_1 : entity work.unpack_telemetry

  unpack_telemetry unpack_1 (
    .clk       (clk_256M),
    // using valid from previous block, so first input will be invalid and missed
    .k_in      (r_data_dec_k),
    .data_in   (r_data_dec),
    .valid_in  (r_valid_dec),
    .data_out  (data_unpack_out),
    .valid_out (valid_unpack_out)
  );

  // check result

  // grab the last data and increment it, to check next data
  // only checking class_id = E for now
  // only checking count
  // proc_data_sync_E : process(clk_256M)

  always @(posedge clk_256M) begin
    if (valid_unpack_out == 1'b1) begin
      if (data_unpack_out[83:80] == 4'hE) begin
        // counter is only for the lower 9 bits, and wraps
        r_data_E[8:0] <= data_unpack_out[8:0] + 9'd1;
      end
    end
  end

  // proc_data_sync_F : process(clk_256M)
  always @(posedge clk_256M) begin
    if (valid_unpack_out == 1'b1) begin
      if (data_unpack_out[83:80] == 4'hF) begin
        r_data_F[8:0] <= data_unpack_out[8:0] + 9'd1;
      end
    end
  end

  // proc_data_check_E : process(clk_256M)
  always @(posedge clk_256M) begin
    if (valid_unpack_out == 1'b1) begin
      if (data_unpack_out[83:80] == 4'hE) begin
        if (data_unpack_out[31:0] == r_data_E) begin
          // data arriving matches expected data
          r_data_match <= 1'b1;
        end else begin
          r_data_match <= 1'b0;
        end
      end else if (data_unpack_out[83:80] == 4'hF) begin
        if (data_unpack_out[31:0] == r_data_F) begin
          // data arriving matches expected data
          r_data_match <= 1'b1;
        end else begin
          r_data_match <= 1'b0;
        end
      end
    end
  end

  initial r_okay_led_out = 1'b0;  

  // generate led that goes on if data is good for > 500 msec
  always @(posedge clk_256M) begin
    if (valid_unpack_out == 1'b1) begin
      r_timeout_cnt <= 16'h0000;
      if (r_data_match == 1'b1) begin
        // valid period of 1.6 usec means 500msec is about 4ffff
        // if (r_match_cnt >= x"4ffff") then
        if (r_match_cnt >= G_MATCH_CNT) begin
          r_okay_led_out <= 1'b1;
        end else begin
          r_match_cnt <= r_match_cnt + 20'd1;
        end
      end else begin
        r_okay_led_out <= 1'b0;
        r_match_cnt    <= 20'h00000;
      end
    end else begin
      // timeout if no valids seen in a bit
      if (r_timeout_cnt == G_TIMEOUT_CNT) begin
        r_okay_led_out <= 1'b0;
      end
      r_timeout_cnt <= r_timeout_cnt + 16'd1;
    end
  end

  // outputs
  assign okay_led_out   = r_okay_led_out;
  assign clk_256M_out   = clk_256M;
  assign pll_locked_out = pll_locked;
  assign data_out       = data_unpack_out;
  assign valid_out      = valid_unpack_out;

  wire _unused_ok = 1'b0 && &{1'b0,
                    clk_128M_buf,
                    1'b0};

endmodule

`resetall
