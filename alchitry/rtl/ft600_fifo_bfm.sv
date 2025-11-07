// ft600_fifo_bfm.sv
// Synthesizable FT600-style FIFO bus functional model (device-side)
// - Parameterizable data width (16/32) and channel count (1/2/4)
// - Active-low RXF#/TXE# flags
// - Tri-stated data/BE bus except during reads
// - Host-side push/pop interfaces to preload RX data and capture TX data
//
// NOTE: Adjust timing/handshake to match your exact FT600 configuration.
//       This model uses a simple, synchronous, one-word-per-cycle scheme.
//       Flags are based on FIFO empty/full status.
//       Channel selection is provided via explicit rd_ch_sel/wr_ch_sel inputs.
//
// Author: (Your Team)
// License: Internal Use

//  you can also get 245 behavior by setting NUM_CH=1 and tying rd_ch_sel/wr_ch_sel to 1’b0

`timescale 1ns / 1ps
`default_nettype none //do not use implicit wire for port connections

module ft600_fifo_bfm #(
    parameter integer DATA_WIDTH     = 32,   // 16 or 32 typical
    parameter integer NUM_CH         = 1,    // 1, 2, or 4
    parameter integer FIFO_DEPTH     = 1024, // per-channel depth
    parameter         USE_BE         = 1     // 1 to use byte enables
) (
    input  wire                        clk, // FT600 actually generates clock
    input  wire                        rst_n,

    // External FT600-style interface toward FPGA logic
    inout  wire [DATA_WIDTH-1:0]       data,        // parallel data bus
    inout  wire [(DATA_WIDTH/8)-1:0]   be,          // byte enables (active high)
    input  wire                        oe_n,        // output enable (active low)
    input  wire                        rd_n,        // read strobe (active low)
    input  wire                        wr_n,        // write strobe (active low)
    output wire [NUM_CH-1:0]           rxf_n,       // RX flags (active low when data available)
    output wire [NUM_CH-1:0]           txe_n,       // TX flags (active low when space available)

    // Channel selection (BFM-side addition; hold stable during transactions)
    input  wire [$clog2(NUM_CH):0]   rd_ch_sel,
    input  wire [$clog2(NUM_CH):0]   wr_ch_sel,

    // Host-side (BFM management) interface:
    // Push data into RX FIFOs (so external logic can read it)
    input  wire                        rx_host_wr_en,
    input  wire [$clog2(NUM_CH):0]   rx_host_wr_ch,
    input  wire [DATA_WIDTH-1:0]       rx_host_wr_data,
    input  wire [(DATA_WIDTH/8)-1:0]   rx_host_wr_be,

    // Pop captured data from TX FIFOs (external logic writes go here)
    input  wire                        tx_host_rd_en,
    input  wire [$clog2(NUM_CH):0]   tx_host_rd_ch,
    output wire                        tx_host_rd_valid,
    output wire [DATA_WIDTH-1:0]       tx_host_rd_data,
    output wire [(DATA_WIDTH/8)-1:0]   tx_host_rd_be
);

    // ----------------------------
    // Internal
    // ----------------------------
    localparam integer BE_WIDTH = (DATA_WIDTH/8);
    localparam integer FIFO_W   = DATA_WIDTH + (USE_BE ? BE_WIDTH : 0);

    // Per-channel RX and TX FIFOs (RX = data available to read, TX = captures writes)
    // Using simple synchronous FIFOs with registered output (one-cycle latency)

    // Arrays for per-channel FIFO signals
    wire [NUM_CH-1:0]                 rx_empty, rx_full;
    wire [NUM_CH-1:0]                 tx_empty, tx_full;

    wire [NUM_CH-1:0]                 rx_push;
    wire [NUM_CH-1:0]                 rx_pop;
    wire [FIFO_W-1:0]                 rx_dout      [0:NUM_CH-1];
    wire [NUM_CH-1:0]                 rx_dout_valid;

    wire [NUM_CH-1:0]                 tx_push;
    wire [NUM_CH-1:0]                 tx_pop;
    wire [FIFO_W-1:0]                 tx_dout      [0:NUM_CH-1];
    wire [NUM_CH-1:0]                 tx_dout_valid;

    // Encoded data word helpers
    function [FIFO_W-1:0] pack_word;
        input [DATA_WIDTH-1:0] d;
        input [BE_WIDTH-1:0]   b;
        begin
            if (USE_BE) begin
                pack_word = {b, d};
            end else begin
                pack_word = { {BE_WIDTH{1'b1}}, d }; // drive full bytes if BE unused
            end
        end
    endfunction

    function [DATA_WIDTH-1:0] unpack_data;
        input [FIFO_W-1:0] w;
        begin
            unpack_data = w[DATA_WIDTH-1:0];
        end
    endfunction

    function [BE_WIDTH-1:0] unpack_be;
        input [FIFO_W-1:0] w;
        begin
            if (USE_BE) begin
                unpack_be = w[DATA_WIDTH + BE_WIDTH - 1 -: BE_WIDTH];
            end else begin
                unpack_be = {BE_WIDTH{1'b1}};
            end
        end
    endfunction

    // ----------------------------
    // Instantiate per-channel FIFOs
    // ----------------------------
    genvar ch;
    generate
        for (ch = 0; ch < NUM_CH; ch = ch + 1) begin : CHANS
            // RX FIFO: host pushes, external logic pops (reads)
            sync_fifo #(
                .WIDTH(FIFO_W),
                .DEPTH(FIFO_DEPTH)
            ) rx_fifo_i (
                .clk        (clk),
                .rst_n      (rst_n),
                .push       (rx_push[ch]),
                .din        ( pack_word(rx_host_wr_data, rx_host_wr_be) ),
                .pop        (rx_pop[ch]),
                .dout       (rx_dout[ch]),
                .dout_valid (rx_dout_valid[ch]),
                .empty      (rx_empty[ch]),
                .full       (rx_full[ch])
            );

            // TX FIFO: external logic pushes (writes), host pops (capture/verify)
            sync_fifo #(
                .WIDTH(FIFO_W),
                .DEPTH(FIFO_DEPTH)
            ) tx_fifo_i (
                .clk        (clk),
                .rst_n      (rst_n),
                .push       (tx_push[ch]),
                .din        ( pack_word(data_in_reg, be_in_reg) ), // captured bus inputs
                .pop        (tx_pop[ch]),
                .dout       (tx_dout[ch]),
                .dout_valid (tx_dout_valid[ch]),
                .empty      (tx_empty[ch]),
                .full       (tx_full[ch])
            );
        end
    endgenerate

    // Host pushes into selected RX channel
    // Demux rx_host_wr_en to rx_push for chosen channel
    reg [NUM_CH-1:0] rx_push_r;
    integer i;
    always @(*) begin
        rx_push_r = {NUM_CH{1'b0}};
        if (rx_host_wr_en) begin
            rx_push_r[rx_host_wr_ch] = 1'b1;
        end
    end
    assign rx_push = rx_push_r;

    // Host pops from selected TX channel
    reg [NUM_CH-1:0] tx_pop_r;
    always @(*) begin
        tx_pop_r = {NUM_CH{1'b0}};
        if (tx_host_rd_en) begin
            tx_pop_r[tx_host_rd_ch] = 1'b1;
        end
    end
    assign tx_pop = tx_pop_r;

    // Provide host readback from TX FIFO (selected channel)
    assign tx_host_rd_valid = tx_dout_valid[tx_host_rd_ch];
    assign tx_host_rd_data  = unpack_data(tx_dout[tx_host_rd_ch]);
    assign tx_host_rd_be    = unpack_be(tx_dout[tx_host_rd_ch]);

    // ----------------------------
    // External interface behavior
    // ----------------------------

    // Flags: active-low
    // RXF# low when RX FIFO (for channel) has data (not empty)
    // TXE# low when TX FIFO (for channel) has space (not full)
    generate
        for (ch = 0; ch < NUM_CH; ch = ch + 1) begin : FLAGS
            assign rxf_n[ch] = rx_empty[ch] ? 1'b1 : 1'b0;
            assign txe_n[ch] = tx_full[ch]  ? 1'b1 : 1'b0;
        end
    endgenerate

    // Capture incoming data/BE on writes (bus driven by external logic)
    // These regs hold sampled bus inputs
    reg [DATA_WIDTH-1:0]     data_in_reg;
    reg [BE_WIDTH-1:0]       be_in_reg;

    // Drive bus on reads (tri-state otherwise)
    reg [DATA_WIDTH-1:0]     bus_out_data;
    reg [BE_WIDTH-1:0]       bus_out_be;
    reg                      bus_out_en; // controls tri-state

    assign data = bus_out_en ? bus_out_data : {DATA_WIDTH{1'bz}};
    assign be   = bus_out_en ? bus_out_be   : {BE_WIDTH{1'bz}};

    // Determine per-cycle read/write activity
    wire rd_active = (oe_n == 1'b0) && (rd_n == 1'b0) && (rxf_n[rd_ch_sel] == 1'b0);
    wire wr_active = (wr_n == 1'b0) && (txe_n[wr_ch_sel] == 1'b0);

    // Demux read pops and connect RX FIFO outputs to bus
    reg [NUM_CH-1:0] rx_pop_r;
    always @(*) begin
        rx_pop_r = {NUM_CH{1'b0}};
        if (rd_active) begin
            rx_pop_r[rd_ch_sel] = 1'b1;
        end
    end
    assign rx_pop = rx_pop_r;

    // Registered bus driving on reads
    // Pop from RX FIFO and present data same cycle (0-cycle latency)
    always @(*) begin
            // Default: disable driving unless valid data follows a pop
            bus_out_en = 1'b0;
            bus_out_data = 16'b0;
            bus_out_be = 2'b0;

            // When RX FIFO indicates valid data after a pop, drive the bus
            if (rx_dout_valid[rd_ch_sel] && (oe_n == 1'b0) && (rd_n == 1'b0)) begin
                bus_out_data = unpack_data(rx_dout[rd_ch_sel]);
                bus_out_be   = unpack_be(rx_dout[rd_ch_sel]);
                bus_out_en   = 1'b1;
            end
    end

    // Capture write data and push into selected TX FIFO
    // Sample bus on rising edge while WR is active
    reg [NUM_CH-1:0] tx_push_r;
    always @(*) begin
        tx_push_r = {NUM_CH{1'b0}};
        if (wr_active) begin
            tx_push_r[wr_ch_sel] = 1'b1;
        end
    end
    assign tx_push = tx_push_r;

    // Sample incoming data/BE during WR
    // If USE_BE==0, we still sample be but ignore it internally
    wire [BE_WIDTH-1:0] be_sample = USE_BE ? be : {BE_WIDTH{1'b1}};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_in_reg <= {DATA_WIDTH{1'b0}};
            be_in_reg   <= {BE_WIDTH{1'b1}};
        end else begin
            if (wr_active) begin
                data_in_reg <= data;
                be_in_reg   <= be_sample;
            end
        end
    end

endmodule

// --------------------------------------
// Simple synchronous FIFO (registered output)
// - One-cycle latency on pop: dout_valid asserted with corresponding data
// - Push when !full, Pop when !empty
// --------------------------------------
module sync_fifo #(
    parameter integer WIDTH = 32,
    parameter integer DEPTH = 1024
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              push,
    input  wire [WIDTH-1:0]  din,
    input  wire              pop,
    output reg  [WIDTH-1:0]  dout,
    output reg               dout_valid,
    output wire              empty,
    output wire              full
);
    // Address width (ceil(log2(DEPTH)))
    function integer clog2;
        input integer value;
        integer v;
        begin
            v = value - 1;
            clog2 = 0;
            while (v > 0) begin
                v = v >> 1;
                clog2 = clog2 + 1;
            end
        end
    endfunction

    localparam AW = clog2(DEPTH);

    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]    wptr;
    reg [AW-1:0]    rptr;
    reg [AW:0]      count;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    // FIFO operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr       <= {AW{1'b0}};
            rptr       <= {AW{1'b0}};
            count      <= {(AW+1){1'b0}};
            dout       <= {WIDTH{1'b0}};
            dout_valid <= 1'b0;
        end else begin
            // Defaults
            dout_valid <= 1'b0;

            // Push
            if (push && !full) begin
                mem[wptr] <= din;
                wptr      <= wptr + 1'b1;
                count     <= count + 1'b1;
            end

            // Pop (registered output with one-cycle latency)
            if (pop && !empty) begin
                dout       <= mem[rptr];
                dout_valid <= 1'b1;
                rptr       <= rptr + 1'b1;
                count      <= count - 1'b1;
            end
        end
    end
endmodule
`resetall
