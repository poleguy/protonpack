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
     input wire clk_52M,
     //input wire clk_256M,

     input wire serial_in_p,
     input wire serial_in_n,

     output wire okay_led_out,
     output wire rst_102M4,

     output wire [31:0] sb_data_rd,
     input wire [31:0] sb_data_wr,
     input wire [23:0] sb_addr,
     input wire sb_wea ,
     input wire sb_rea

   );

  // More signals declaration similar to VHDL

  reg r_rst_self_102M4_n = 0;
  reg [4:0] r_rst_self_cnt_102M4 = 0;
  wire okay_led;
  wire cnt_led_out;
  wire [87:0] data_out;
  wire [87:0] fifo_data_out;
  wire valid_out;
  wire pll_locked;
  wire clk_256M;
  wire empty;
  wire full;
  reg fifo_read_en = 1'b0;
  reg [31:0] r_sb_data_rd = 32'h0;

  // Internal registers for storage
  reg [31:0] memory [0:3]; // Memory array for locations 0, 1, 2, and 3

  wire one = 1'b1;

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
  assign sb_data_rd = r_sb_data_rd;

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


  // Instance of the FIFO module
  afifo fifo_inst (
    .i_wclk(clk_256M),
    .i_wrst_n(one),
    .i_rclk(clk_52M),
    .i_rrst_n(one),
              .i_wr(valid_out),
              .i_rd(fifo_read_en),
              .i_wdata(data_out),
              .o_rdata(fifo_data_out),
              .o_rempty(empty),
              .o_wfull(full)
            );


  always @(posedge clk_52M)
  begin
    begin
      // Write to memory if write_en is high
      if (sb_wea)
      begin
        case (sb_addr[3:0])
          4'h0:
            memory[0] <= sb_data_wr;
          4'h1:
            memory[1] <= sb_data_wr;
          4'h2:
            memory[2] <= sb_data_wr;
          4'h3:
            memory[3] <= sb_data_wr;
        endcase
      end

      fifo_read_en <= 1'b0;
      // Read data from appropriate memory location
      case (sb_addr[3:0])
        4'h0:
          r_sb_data_rd <= memory[0];
        4'h1:
          r_sb_data_rd <= memory[1];
        4'h2:
          r_sb_data_rd <= memory[2];
        4'h3:
          r_sb_data_rd <= memory[3];
        4'h4:
          r_sb_data_rd <= fifo_data_out[31:0];
        4'h5:
          r_sb_data_rd <= fifo_data_out[63:32];
        4'h6:
          r_sb_data_rd <= {8'h00, fifo_data_out[87:64]};
        4'h7:
        begin
          r_sb_data_rd <= {31'h00, empty};  // don't look at full. We can embed a counter to check for drops.
          fifo_read_en <= 1'b1;
        end
        default:
          r_sb_data_rd <= 32'h1badc0de; // Default case for addresses not defined
      endcase
    end
  end

endmodule
`default_nettype wire // turn it off
