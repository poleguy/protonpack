`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

import version_pkg::*;
    /* verilator lint_off UNOPTFLAT */
module alchitry_top (
        input wire clk,
        input wire rst_n,
        output wire [7:0] led,
        input wire usb_rx,
        output wire usb_tx,
        input wire ft_clk,
        input wire ft_rxf,
        input wire ft_txe,
        inout wire [15:0] ft_data,
        inout wire [1:0] ft_be,
        output wire ft_rd,
        output wire ft_wr,
        output wire ft_oe,
        output wire ft_wakeup,
        output wire ft_reset,
        input wire RXN_I,
        input wire RXP_I,
        input wire [0:0] GTREFCLK1P_I,
        input wire [0:0] GTREFCLK1N_I,
        output wire REC_CLOCK_P,
        output wire REC_CLOCK_N,
        // BOT_ indicates bottom side Pt board pins
        // they are labeled to match top side pin numbers and Br Breakout board silk screen
        output wire BOT_B30,
        output wire BOT_B28,
        input wire BOT_B3,
        input wire BOT_B5,
        input wire BOT_B4,
        output wire BOT_B6,
        // led outputs mimicked on connector C bottom side.
        output wire [7:0] BOT_C_L

    );
    wire rst;
    wire clk_wiz_reset;
    wire M_reset_cond_in;
    wire M_reset_cond_out;
    wire clk_100M; // to rename it post MMCM
    wire clk_128M;
    wire clk_wiz_locked;
    reg r_clk_wiz_locked_128M = 1'b0;
    reg r1_clk_wiz_locked_128M = 1'b0;
    //   reg r_clk_wiz_locked_256M = 1'b0;
    //   reg r1_clk_wiz_locked_256M = 1'b0;
    reg r_rst_128M = 1'b0;
    reg r_rst_256M = 1'b0;
    wire clk_256M;
    wire [31:0] gt_data;
    wire [3:0] gt_data_is_k;
    wire [87:0] packet_data;
    wire packet_valid;
    // wire stream_clk0;
    // wire stream_valid0;
    // wire [31:0] stream_enable0;
    // wire [87:0] stream_data0;
    wire gt_clk;
    reg reset_counters = 0;
    wire [31:0] total_packets;
    wire [31:0] mismatch_packets;
    wire okay_led;
    wire link_count_okay;
    wire gt_soft_reset;
    //wire [47:0] tx_mac_dest;
    parameter FREQ_CNT_VAL = 16'h0800;

    //wire M_ft_ft_rxf;
    //wire M_ft_ft_txe;
    //wire M_ft_ft_rd;
    //wire M_ft_ft_wr;
    //wire M_ft_ft_oe;

    reg [15:0] M_ft_ui_din;
    reg [1:0] M_ft_ui_din_be;
    reg M_ft_ui_din_valid;
    wire M_ft_ui_din_full;

    wire [15:0] M_ft_ui_dout;
    wire [1:0] M_ft_ui_dout_be;
    wire M_ft_ui_dout_empty;
    reg M_ft_ui_dout_get;
    wire blinky_led;
    //  wire blinky_led_100M;
    wire blinky_led_ft;

    reg [15:0] r_serial_in;
    reg r_serial_in_valid;

    reg [3:0] r_cnt = 4'hf;
    reg [15:0] r_packet_cnt = 16'h0;
    reg r_packet_valid;
    reg r1_packet_valid;
    reg r_packet_valid_128;
    wire [1:0] btn_state;
    wire [1:0] btn_raw;
    wire sample_tick;
    wire ft_loopback_mode;
    reg r_sticky_overflow = 1'b0;


    // esm io
    // i/O

    reg  [7:0]  r_databusin = 8'h00;
    wire [7:0]  databusout;
    wire [7:0]  addrbus;
    wire [15:0] addr4to16;
    wire        rs_wr;
    wire        rs_re;

    // Additional signals used below (declare/size appropriately in your design)
    wire               UART_TX;
    wire               UART_RX;

    // reg         r_wr_sys;
    // reg         r1_wr_sys;
    // reg         wr_sys;

    reg  [31:0] addr;
    reg  [31:0] data_in;
    reg  [31:0] data;

    wire [31:0] VERSION;
    wire [63:0] r_memdatain;

    reg         rd32;
    reg         wr32;
    wire [7:0]  r_addr10to1F;


    initial begin
        //$dumpfile();                // default "dump.vcd"
        $dumpfile("wave1.fst");     // dumps into "wave1.gst"
    end

    initial begin
        $dumpvars (0);        // Dumps all variables from all module instances

    end
    reset_conditioner #(.STAGES(3'h4)) reset_cond(
                          .clk(clk_128M),
                          .in(M_reset_cond_in),
                          .out(M_reset_cond_out)
                      );
    ft #(
           .BUS_WIDTH(5'h10),
           .TX_BUFFER(2048),
           .RX_BUFFER(2048),
           .PRIORITY_TX(0),
           .PREEMPT(1'h0)
       ) ft(
           .ft_clk(ft_clk),
           .ft_data(ft_data),
           .ft_be(ft_be),
           .clk(clk_128M), // switch back to see if it will fix the drops/repeats at interface
           .rst(rst),
           .ft_rxf(ft_rxf),
           .ft_txe(ft_txe),
           .ft_rd(ft_rd),
           .ft_wr(ft_wr),
           .ft_oe(ft_oe),
           .ui_din(M_ft_ui_din),
           .ui_din_be(M_ft_ui_din_be),
           .ui_din_valid(M_ft_ui_din_valid),
           .ui_din_full(M_ft_ui_din_full),
           .ui_dout(M_ft_ui_dout),
           .ui_dout_be(M_ft_ui_dout_be),
           .ui_dout_empty(M_ft_ui_dout_empty),
           .ui_dout_get(M_ft_ui_dout_get)
       );


    //always @(*) begin
    assign M_reset_cond_in = !rst_n;
    assign rst = M_reset_cond_out;
    assign led = {blinky_led,blinky_led_ft, ft_loopback_mode,sample_tick,ft_txe, ft_rxf, M_ft_ui_dout_empty, M_ft_ui_din_full};
    assign BOT_C_L = led;
    assign usb_tx = usb_rx;
    assign ft_wakeup = 1'h1;
    assign ft_reset = !rst;

    assign clk_wiz_reset = !rst_n;

    
    clk_wiz_100M clk_wiz_100M_i(
                     .clk_in1(clk),
                     .reset(clk_wiz_reset),
                     .clk_out1(clk_128M),
                     .clk_out2(clk_100M),
                     .locked(clk_wiz_locked)
                 );

    always @(posedge clk_128M) begin
        r_clk_wiz_locked_128M <= clk_wiz_locked;
        r1_clk_wiz_locked_128M <= r_clk_wiz_locked_128M;
        if (r1_clk_wiz_locked_128M == 0)
            r_rst_128M <= 1;
        else
            r_rst_128M <= 0;
    end
    //   always @(posedge clk_256M) begin
    //     r_clk_wiz_locked_256M <= clk_wiz_locked;
    //     r1_clk_wiz_locked_256M <= r_clk_wiz_locked_256M;
    //     if (r1_clk_wiz_locked_256M == 0)
    //       r_rst_256M <= 1;
    //     else
    //       r_rst_256M <= 0;
    //   end

    // it seems this stupid board doesn't have any non 3.3V banks. ugh.
    // try to fake differential for the clock:

    assign REC_CLOCK_P = clk_128M;
    assign REC_CLOCK_N = ~clk_128M;

    gt_serial_telem_rx_subsystem gt_serial_telem_rx_subsystem(
                                     .Q0_CLK1_GTREFCLK_PAD_N_IN(GTREFCLK1N_I[0]),
                                     .Q0_CLK1_GTREFCLK_PAD_P_IN(GTREFCLK1P_I[0]),
                                     .DRP_CLK_IN(clk_128M),
                                     .RST_128M(r_rst_128M),
                                     .SOFT_RESET_OUT(gt_soft_reset),
                                     .RXN_IN(RXN_I),
                                     .RXP_IN(RXP_I),
                                     .TXN_OUT(),
                                     .TXP_OUT(),
                                     .DATA_CLK_OUT(gt_clk), //RXUSRCLK2
                                     .DATA_OUT(gt_data),
                                     .DATA_IS_K_OUT(gt_data_is_k)
                                 );
    gt_unpack_telemetry gt_unpack_telemetry(
                            .clk_128M(clk_128M),
                            .rst_128M(r_rst_128M),
                            .gt_clk(gt_clk),
                            .gt_data(gt_data),
                            .gt_data_is_k(gt_data_is_k),
                            .clk_256M_out(clk_256M),
                            .pll_locked_out(),
                            .okay_led_out(),
                            .cnt_led_out(),
                            .data_out(packet_data),
                            .valid_out(packet_valid)
                        );
    telemetry_check telemetry_check(
                        .clk_256M(clk_256M),
                        .packet_data(packet_data),
                        .packet_valid(packet_valid),
                        .reset_counters(reset_counters),
                        .total_packets(total_packets),
                        .mismatch_packets(mismatch_packets),
                        .okay_led(okay_led),
                        .link_count_okay(link_count_okay)
                    );

    blink_led blink_led(
                  .clk_128M(clk_128M),
                  .led(blinky_led)
              );

    blink_led blink_led_ft(
                  .clk_128M(ft_clk),
                  .led(blinky_led_ft)
              );


    assign BOT_B30 = gt_clk;
    assign BOT_B28 = gt_data_is_k[0];


    // drive the serial data out of the FT interface for debug:

    always @(posedge clk_128M) begin
        if (r_cnt == 4'h0) begin
            r_serial_in <= packet_data[15:0];
            r_serial_in_valid <= 1'b1;
        end
        else if (r_cnt == 4'h1) begin
            r_serial_in <= packet_data[31:16];
        end
        else if (r_cnt == 4'h2) begin
            r_serial_in <= packet_data[47:32];
        end
        else if (r_cnt == 4'h3) begin
            r_serial_in <= packet_data[63:48];
        end
        else if (r_cnt == 4'h4) begin
            r_serial_in <= packet_data[79:64];
        end
        else if (r_cnt == 4'h5) begin
            // insert "|" character to make it easier to debug.
            r_serial_in <= {8'h7C, packet_data[87:80]};
        end
        else if (r_cnt == 4'h6) begin
            // extra magic word for debug: "CODE"
            r_serial_in <= {16'hDEC0};
        end
        else if (r_cnt == 4'h7) begin
            r_serial_in <= r_packet_cnt;
        end
        else begin
            // send k character when idle (default)
            r_serial_in <= 16'hBCBC;
            r_serial_in_valid <= 1'b0;
        end
    end


    // count bytes
    always @(posedge clk_128M) begin
        if (r_packet_valid_128) begin
            // start count
            r_cnt <= 4'h0;
        end
        else if (r_cnt > 4'h7) begin
            // stop counting when all bytes are sent and wait for next valid_in
            r_cnt <= 4'h8;
        end
        else begin
            // count for each byte of data
            r_cnt <= r_cnt + 4'h1;
        end

    end


    // count packets to see if FT600 is dropping words.
    always @(posedge clk_128M) begin
        if (r_packet_valid_128) begin
            r_packet_cnt <= r_packet_cnt + 16'h1;
        end

    end


    //stretch into 128MHz clock domain

    always @(posedge clk_256M) begin
        if (packet_valid) begin
            r_packet_valid <= 1'b1;
        end
        else begin
            r_packet_valid <= 1'b0;
        end
        r1_packet_valid <= r_packet_valid;

        r_packet_valid_128 <= r_packet_valid || r1_packet_valid;
    end

//  todo: add free running counter as a timer.
//    timestamp all packet_valid times.
//      send them along with the packet
//        maybe send a total of 32 bytes so that it's easy to decode in hexl-mode
//  then we can tell if any drop.
//
//    todo: hook up esm
//      todo: debug stoppage after first 4k after config
//
//  todo: debug with scope and leds/test points.
//
//    todo: test serial port (in sim?/on hardware?)
//      todo: control loopback mode with esm/serial
//        todo: use a timer starting at bootup to time events of the first 4096 captures.
//          todo: esm readback of full/empty/etc.

    // two modes, here:
    // 0 = loopback from pc
    // 1 = stream from telemetry

    // back to direct loopback as in original to try to see if it fixes the drops
//    assign M_ft_ui_dout_get = !M_ft_ui_din_full;
//    assign M_ft_ui_din_valid = !M_ft_ui_dout_empty;
//    assign M_ft_ui_din = M_ft_ui_dout;
//    assign M_ft_ui_din_be = M_ft_ui_dout_be;

    always @(*) begin
        if (ft_loopback_mode) begin
            M_ft_ui_din = M_ft_ui_dout;
            M_ft_ui_din_be = M_ft_ui_dout_be;
            M_ft_ui_din_valid = !M_ft_ui_dout_empty;
            M_ft_ui_dout_get = !M_ft_ui_din_full;
        end
        else begin
            M_ft_ui_din = r_serial_in;
            M_ft_ui_din_be = 2'b11;
            M_ft_ui_din_valid = r_serial_in_valid;
            M_ft_ui_dout_get = 1'b1;
        end
    end

    always @(posedge clk_128M) begin
       if (r_serial_in_valid & M_ft_ui_din_full) begin
          r_sticky_overflow = 1'b1;
       end
    end

    // handle switch inputs

    assign btn_raw = {BOT_B5, BOT_B3};

    // bypassing debounce to see if it is at least hooked up right
    //assign ft_loopback_mode = btn_state[0];
    assign ft_loopback_mode = btn_raw[0];

    // Debouncer instance
    toggle_debounce #(
                        .N(2)
                    ) toggle_debounce (
                        .clk   (clk_128M),
                        .tick  (sample_tick),
                        .raw_in(btn_raw),
                        .state (btn_state)
                    );

    tick_gen #(
                 .COUNTER_SIZE(18) // target 2ms at 128MHz clock
             ) tick_gen (
                 .clk(clk_128M),     // input clock
                 .prescaler (sample_tick) // to use a shared external prescaler counter
             );

    // esm with serial port for control



    // --------------------------------------------------------------------------------
    // clock domain crossing
    // --------------------------------------------------------------------------------
    //  shrink re and wr to sys clock length
    // reclock at higher rate
    // always @(posedge clk_sys) begin
    //   r_wr_sys  <= rs_wr;
    //   r1_wr_sys <= r_wr_sys;
    //   // rising edge detect
    //   wr_sys    <= (~r1_wr_sys) & (r_wr_sys);
    // end

    rs_core #(
                .prog_path ("./esm_dir/rs232io_32bit_dump.hex"),
                .prog_depth(10),
                .clk_freq  (128000000),
                .baud_rate (115200)
            ) rs_core_0 (
                .serial_out(UART_TX),
                .serial_in (UART_RX),
                .clk       (clk_128M),
                .RESET     (1'b0),
                .databusin (r_databusin),
                .databusout(databusout),
                .addrbus   (addrbus),
                .addr4to16 (addr4to16),
                .wr        (rs_wr),
                .re        (rs_re),
                .extint    (1'b0),
                .dms       (3'b110)
            );


    assign UART_RX = BOT_B4;
    assign BOT_B6 = UART_TX;

    // Readback MUX, 8 bit
    always @(posedge clk_128M) begin
        case ({4'h0, addrbus[7:0]})
            12'h010: begin
                r_databusin <= addr[31:24];
            end
            12'h011: begin
                r_databusin <= addr[23:16];
            end
            12'h012: begin
                r_databusin <= addr[15:8];
            end
            12'h013: begin
                r_databusin <= addr[7:0];
            end
            12'h014: begin
                r_databusin <= data_in[31:24];
            end
            12'h015: begin
                r_databusin <= data_in[23:16];
            end
            12'h016: begin
                r_databusin <= data_in[15:8];
            end
            12'h017: begin
                r_databusin <= data_in[7:0];
            end
            12'h018: begin
                // bus width
                r_databusin <= 8'h02;
            end
            default: begin
                r_databusin <= 8'h00;
            end
        endcase
    end

    // Readback MUX 32 bit
    always @(posedge clk_128M) begin
        // clear on read
        data_in                <= {24'h000000, 8'h00}; // default to prevent accidental registers

        case ({4'h0, addr[7:0]})
            12'h000: begin
                // version
                data_in <= {version_pkg::C_VERSION_MAJOR, version_pkg::C_VERSION_MINOR, version_pkg::C_VERSION_PATCH, version_pkg::C_VERSION_BUILD}; //VERSION[31:0];

            end
            12'h013: begin
                //if (g_fifo > 0) begin
                data_in <= r_memdatain[31:0];
                //end
            end

            12'h014: begin
                // triggers read ahead for next set of data
                //if (g_fifo > 0) begin
                data_in <= r_memdatain[63:32];
                //end
            end

            // 12'h017: begin
            //   //if (g_fifo > 0) begin
            //     // write causes memrst
            //     data_in <= {1'b0, r_fifo_triggered, r_fifo_pre_triggered, r_fifo_trig_en,
            //                 1'b0, r_fifo_trig_mode, r_fifo_preload_mode,
            //                 16'h0000,
            //                 2'b00, r_fifo_full, r_fifo_empty,
            //                 4'b0000};
            //   //end
            // end


            default: begin
                data_in <= {24'h000000, 8'h00};
            end
        endcase
    end

    // generate 32bit register controls from 8 bit controls
    always @(posedge clk_128M) begin
        rd32 <= 1'b0;
        wr32 <= 1'b0;

        // version register
        if (rs_wr == 1'b1 && r_addr10to1F[0] == 1'b1) begin
            addr[31:24] <= databusout[7:0];
        end

        // type register
        if (rs_wr == 1'b1 && r_addr10to1F[1] == 1'b1) begin
            addr[23:16] <= databusout[7:0];
        end

        // test register
        if (rs_wr == 1'b1 && r_addr10to1F[2] == 1'b1) begin
            //       b_test(7 downto 0) <= databusout(7 downto 0);
            addr[15:8] <= databusout[7:0];
        end

        if (rs_wr == 1'b1 && r_addr10to1F[3] == 1'b1) begin
            // low byte
            addr[7:0] <= databusout[7:0];
            // rs_write causes 32 bit read to data(31 downto 0)
            rd32       <= 1'b1;
        end

        if (rs_wr == 1'b1 && r_addr10to1F[4] == 1'b1) begin
            // register high byte
            data[31:24] <= databusout[7:0];
        end

        if (rs_wr == 1'b1 && r_addr10to1F[5] == 1'b1) begin
            // register high byte
            data[23:16] <= databusout[7:0];
        end

        if (rs_wr == 1'b1 && r_addr10to1F[6] == 1'b1) begin
            // register high byte
            data[15:8] <= databusout[7:0];
        end

        if (rs_wr == 1'b1 && r_addr10to1F[7] == 1'b1) begin
            // register high byte
            data[7:0] <= databusout[7:0];
            // write causes 32 bit write to addr(31 downto 0) of data(31 downto 0)
            wr32       <= 1'b1;
        end
    end


    wire _unused_ok = 1'b0 && &{1'b0,
                                r_rst_256M,
                                // stream_clk0,
                                // stream_valid0,
                                // stream_enable0,
                                // stream_data0,
                                mismatch_packets,
                                okay_led,
                                total_packets,
                                link_count_okay,
                                gt_soft_reset,
                                FREQ_CNT_VAL,
                                1'b0};
    /* verilator lint_on UNOPTFLAT */

endmodule

`resetall
