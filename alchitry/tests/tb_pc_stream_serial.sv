`timescale 1ns/1ps

/*-------------------------------------------------------------------------------
-- Company: Shure, Inc.
--
--
-------------------------------------------------------------------------------*/

module tb_pc_stream_serial;

  // Signal declarations (equivalent to VHDL std_logic)
  logic DATA_P;
  logic DATA_N;
  logic SYSCLKP_I;
  logic SYSCLKN_I;
  logic user_clk_p;
  logic user_clk_n;

  // Local "generics" as parameters/constants
  localparam bit G_SIM = 1'b1;

  // Clocks (initialized to 0, as in VHDL)
  logic clk_128 = 1'b0;
  logic clk_64  = 1'b0;


  // System clock and reset
  reg clk_100   = 1'b0;
  reg rst_n = 1'b0;
  wire rst;

  // USB
  reg  usb_rx = 1'b0;
  wire usb_tx;

  // FT interface
  reg         ft_clk = 1'b0;
  reg         ft_rxf = 1'b1;
  reg         ft_txe = 1'b1;
  wire [15:0] ft_data;   // Inout from DUT; TB does not drive
  wire [1:0]  ft_be;     // Inout from DUT; TB does not drive
  wire        ft_rd;
  wire        ft_wr;
  wire        ft_oe;
  wire        ft_wakeup;
  wire        ft_reset;

  // Transceiver inputs (kept static for this basic TB)
  reg        RXN_I = 1'b0;
  reg        RXP_I = 1'b0;
  reg [0:0]  GTREFCLK1P_I = 1'b0;
  reg [0:0]  GTREFCLK1N_I = 1'b0;

  // DUT outputs
  wire [7:0] led;
  wire REC_CLOCK_P;
  wire REC_CLOCK_N;
  wire [87:0] packet;
  wire packet_valid;
  wire telemetry_trigger;
  reg telemetry_request;
  localparam integer rate_count = 100;

  // INPUT INITIALIZATION - Can initialize VHDL inputs to 0 OK, but for Verilog telem_mobile_ac701
  // this is not working. So we have to have signals here and cocotb drive these signals versus
  // going 1 level down into telem_mobile_ac701.


  // 64 MHz clock: VHDL process toggles once and then stops (replicated here).
  initial begin
    forever begin
      #7.808 clk_64 = ~clk_64;
    end
  end

  // 
  initial begin
    forever begin
      #5.000 clk_100 = ~clk_100;
    end
  end

   // actually comes from ft600 on hardware
  initial begin
    forever begin
      #5.000 ft_clk = ~ft_clk;
    end
  end

  // If continuous clocks are desired, use the following alternatives:
  // initial begin
  //     forever begin
  //         #3.90625 clk_128 = ~clk_128; // 128 MHz -> 7.8125 ns period
  //     end
  // end
  //
  // initial begin
  //     forever begin
  //         #7.8125 clk_64 = ~clk_64; // 64 MHz -> 15.625 ns period
  //     end
  // end

  // cocotb will drive other inputs, eg. adc1_data

  // since this is code is not intended to be proprietary, we won't include a top level transmitter design.
  // instead we'll just have a serializer.
  // But it will talk to the top level of the protonpack design.

  //todo: drop in a generator block based on dpsm_top. It'll need to be isolated.
  // dpsm_top #(
  //     .include_telem(1'b1)
  // ) dpsm (
  //     .FPGA_DEBUG_SDIN0     (DATA_P),
  //     .FPGA_DEBUG_SDIN1     (DATA_N),
  //     .clk_128mhz_fpga      (clk_128),
  //     .clk_64mhz_fpga_1v8   (clk_64)
  // );

  reg clk_256 = 0;
  reg clk_512 = 0;

  // Generate system clock: 100 MHz (10 ns period)
  localparam real CLK_PERIOD_NS = 10.0;

  // INPUT INITIALIZATION - Can initialize VHDL inputs to 0 OK, but for Verilog telem_mobile_ac701
  // this is not working. So we have to have signals here and cocotb drive these signals versus
  // going 1 level down into telem_mobile_ac701.

  initial begin
    forever begin
      #3.904 clk_128 = ~clk_128;
    end
  end

  initial begin
    forever begin
      #1.952 clk_256 = ~clk_256;
    end
  end

  initial begin
    forever begin
      #0.976 clk_512 = ~clk_512;
    end
  end



  // Basic stimulus
  initial begin
    // Apply reset
    rst_n = 1'b0;
    #(10*CLK_PERIOD_NS);
    rst_n = 1'b1;

  end
  assign rst = ~rst_n;

  always @(posedge clk_128) begin
    if (telemetry_trigger == 1'b1) begin
      telemetry_request <= 1'b1;
    end
    else begin
        telemetry_request <= 1'b0;
    end

  end
  telemetry_test_counter telemetry_test_counter (
                           .clk_128MHz(clk_128),
                           .rate(rate_count), // reuse for counter and metadata rate for now. fpgapoke 0x2c21
                           .telemetry_trigger(telemetry_trigger),
                           .telemetry_request(telemetry_request),
                           //.telemetry_addr(),
                           .telemetry_data(packet),
                           .telemetry_data_valid(packet_valid)
                         );

  // cocotb will drive other inputs, eg. packet, packet_valid
  // list all ports to avoid cvc warning:
  // WARN** [531] telemetry_serialize_inst(telemetry_serialize) explicit connection list fewer ports 7 connected than type's 8

  telemetry_serialize telemetry_serialize (
                        .clk(clk_128),
                        .clk4x(clk_512),
                        .reset_clk(rst),
                        .packet(packet),
                        .packet_valid(packet_valid),
                        .serializer_ready(),
                        .O(),
                        .OB()

                      );

  // packet and packet_valid will be copied back and forth using cocotb


  // Device Under Test
  alchitry_top alchitry_top (
                 .clk(clk_100),
                 .rst_n(rst_n),
                 .led(led),
                 .usb_rx(usb_rx),
                 .usb_tx(usb_tx),
                 .ft_clk(ft_clk),
                 .ft_rxf(ft_rxf),
                 .ft_txe(ft_txe),
                 .ft_data(ft_data),
                 .ft_be(ft_be),
                 .ft_rd(ft_rd),
                 .ft_wr(ft_wr),
                 .ft_oe(ft_oe),
                 .ft_wakeup(ft_wakeup),
                 .ft_reset(ft_reset),
                 .RXN_I(RXN_I),
                 .RXP_I(RXP_I),
                 .GTREFCLK1P_I(GTREFCLK1P_I),
                 .GTREFCLK1N_I(GTREFCLK1N_I),
                 .REC_CLOCK_P(REC_CLOCK_P),
                 .REC_CLOCK_N(REC_CLOCK_N),
    .BOT_B30(),
    .BOT_B28(),
    .BOT_B5(),
    .BOT_B3(1'b0), // loopback mode toggle switch 1 == loopback
    .BOT_B6(),
    .BOT_B4(),
    .BOT_C_L()
               );

  localparam DATA_WIDTH = 32;
  localparam NUM_CH     = 2;
  localparam BE_WIDTH   = DATA_WIDTH/8;
     // FT600-side signals (connect these to your DUT)
//  wire [DATA_WIDTH-1:0] ft_data;
//  wire [BE_WIDTH-1:0]   ft_be;
  //wire                  oe_n;   // driven by DUT
  //wire                  rd_n;   // driven by DUT
  //wire                  wr_n;   // driven by DUT
//   wire [NUM_CH-1:0]     rxf_n;  // observed by DUT
//   wire [NUM_CH-1:0]     txe_n;  // observed by DUT
  reg  [0:0] rd_ch_sel = 0; // channel DUT intends to read
  reg  [0:0] wr_ch_sel = 0; // channel DUT intends to write

  // Host-side (BFM management) signals
  reg                        rx_host_wr_en  = 0;
  reg  [$clog2(NUM_CH)-1:0]  rx_host_wr_ch  = 0;
  reg  [DATA_WIDTH-1:0]      rx_host_wr_data= 32'hCAFEBABE;
  reg  [BE_WIDTH-1:0]        rx_host_wr_be  = {BE_WIDTH{1'b1}};

  reg                        tx_host_rd_en  = 0;
  reg  [$clog2(NUM_CH)-1:0]  tx_host_rd_ch  = 0;
  wire                       tx_host_rd_valid;
  wire [DATA_WIDTH-1:0]      tx_host_rd_data;
  wire [BE_WIDTH-1:0]        tx_host_rd_be;


  // Instantiate the FT600 FIFO BFM
  ft600_fifo_bfm #(
    .DATA_WIDTH (16),
    .NUM_CH     (1),
    .FIFO_DEPTH (32), // small to be under verilator --trace-max-array limit
    .USE_BE     (1)
  ) u_ft600 (
    .clk              (ft_clk),
    .rst_n            (ft_reset),
    .data             (ft_data),
    .be               (ft_be),
    .oe_n             (ft_oe),
    .rd_n             (ft_rd),
    .wr_n             (ft_wr),
    .rxf_n            (ft_rxf),
    .txe_n            (ft_txe),
    .rd_ch_sel        (rd_ch_sel),
    .wr_ch_sel        (wr_ch_sel),
    .rx_host_wr_en    (rx_host_wr_en),
    .rx_host_wr_ch    (rx_host_wr_ch),
    .rx_host_wr_data  (rx_host_wr_data),
    .rx_host_wr_be    (rx_host_wr_be),
    .tx_host_rd_en    (tx_host_rd_en),
    .tx_host_rd_ch    (tx_host_rd_ch),
    .tx_host_rd_valid (tx_host_rd_valid),
    .tx_host_rd_data  (tx_host_rd_data),
    .tx_host_rd_be    (tx_host_rd_be)
  );

// Quick demo: preload one RX word on channel 0
  initial begin
    @(posedge ft_reset);

     // isolated write
    @(posedge ft_clk); 
    rx_host_wr_ch   = 0;
    rx_host_wr_be   = {BE_WIDTH{1'b1}};
    rx_host_wr_data = 32'hDEADBEEF;
    rx_host_wr_en   = 1; 
    @(posedge ft_clk); 
    rx_host_wr_en = 0;
    rx_host_wr_data = 32'h0;
    // Now rxf_n[0] will be low; your DUT can read via oe_n/rd_n on ch 0.

     // space it out for ease of debug
     repeat (20) begin
        @(posedge ft_clk);
     end

     // two back to back word writes
    @(posedge ft_clk); 
    rx_host_wr_data = 16'hAA00;
    rx_host_wr_en   = 1; 
    @(posedge ft_clk); 
    rx_host_wr_en = 1;
    rx_host_wr_data = 32'hBB01;
    @(posedge ft_clk); 
    rx_host_wr_en = 0;
    rx_host_wr_data = 32'h0;

     // space it out for ease of debug
     repeat (20) begin
        @(posedge ft_clk);
     end

     // two back to back word writes
    @(posedge ft_clk); 
    rx_host_wr_data = 16'hAA02;
    rx_host_wr_en   = 1; 
    @(posedge ft_clk); 
    rx_host_wr_en = 1;
    rx_host_wr_data = 32'hBB03;
    @(posedge ft_clk); 
    rx_host_wr_en = 0;
    rx_host_wr_data = 32'h0;

     // space it out for ease of debug
     repeat (20) begin
        @(posedge ft_clk);
     end

     // have the host then drain out some of the fifo and check it
     // todo: maybe it's not necessary to even have a tx_fifo to the host
     // todo: do all this in cocotb?
     // todo: check: dout and dout_valid should read these correctly:
    @(posedge ft_clk); 
    tx_host_rd_en = 1; // beef
    @(posedge ft_clk); 
    tx_host_rd_en = 1; // aa00
    @(posedge ft_clk); 
    tx_host_rd_en = 1; // bb01
    @(posedge ft_clk); 
    tx_host_rd_en = 0;

     
     
  end

  // TODO: Instantiate and connect your DUT to ft_* signals above.
  // Example:
  // my_ft600_client dut (
  //   .clk    (clk),
  //   .rst_n  (rst_n),
  //   .data   (ft_data),
  //   .be     (ft_be),
  //   .oe_n   (oe_n),
  //   .rd_n   (rd_n),
  //   .wr_n   (wr_n),
  //   .rxf_n  (rxf_n),
  //   .txe_n  (txe_n)
  // );

   
endmodule

`resetall
