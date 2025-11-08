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
            // RX FIFO: host pushes, external logic pops (reads) (FWFT)
            fwft_fifo #(
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
                .din        ( pack_word(data, be_sample) ), // captured bus inputs
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
    // RXF# reflects immediate availability (FWFT dout_valid)
    generate
        for (ch = 0; ch < NUM_CH; ch = ch + 1) begin : FLAGS
            assign rxf_n[ch] = rx_dout_valid[ch] ? 1'b0 : 1'b1; // low when a word is ready now
            assign txe_n[ch] = tx_full[ch]        ? 1'b1 : 1'b0; // low when space available
        end
    endgenerate

    // Read activity: same-cycle bus drive when OE#/RD# low and data ready on selected channel
    wire rd_can_drive = (oe_n == 1'b0) && (rd_n == 1'b0) && rx_dout_valid[rd_ch_sel];

    // Pop current word on RD (consume FWFT output register)
    reg [NUM_CH-1:0] rx_pop_r;
    always @(*) begin
        rx_pop_r = {NUM_CH{1'b0}};
        if (rd_can_drive) begin
            rx_pop_r[rd_ch_sel] = 1'b1;
        end
    end
    assign rx_pop = rx_pop_r;

    // Combinational bus drive for same-cycle data
    wire [DATA_WIDTH-1:0] rx_bus_data = unpack_data(rx_dout[rd_ch_sel]);
    wire [BE_WIDTH-1:0]   rx_bus_be   = unpack_be(rx_dout[rd_ch_sel]);

    assign data = rd_can_drive ? rx_bus_data : {DATA_WIDTH{1'bz}};
    assign be   = rd_can_drive ? rx_bus_be   : {BE_WIDTH{1'bz}};

    // Write path (unchanged): sample incoming data/BE during WR and push into TX FIFO
    wire wr_active = (wr_n == 1'b0) && (txe_n[wr_ch_sel] == 1'b0);

//    reg [DATA_WIDTH-1:0]     data_in_reg;
//    reg [BE_WIDTH-1:0]       be_in_reg;
    wire [BE_WIDTH-1:0]      be_sample = USE_BE ? be : {BE_WIDTH{1'b1}};

//    always @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            data_in_reg <= {DATA_WIDTH{1'b0}};
//            be_in_reg   <= {BE_WIDTH{1'b1}};
//        end else if (wr_active) begin
//            data_in_reg <= data;
//            be_in_reg   <= be_sample;
//        end
//    end

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

endmodule

// ------------------------------
// First-Word Fall-Through FIFO (FWFT) for RX
// dout_valid=1 when dout holds a word ready to be read this cycle.
// Capacity = DEPTH; occupancy = count + out_valid.
// ------------------------------
// Corrected First-Word Fall-Through (FWFT) FIFO
// - Bypasses din directly to dout when output is empty and MEM has no data
// - Refills dout from MEM when pre-existing data is available (count > 0)
// - Prevents read-before-write and wrong-word issues on first push/pop
module fwft_fifo #(
    parameter integer WIDTH = 32,
    parameter integer DEPTH = 1024
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             push,
    input  wire [WIDTH-1:0] din,
    input  wire             pop,
    output reg  [WIDTH-1:0] dout,
    output reg              dout_valid,
    output wire             empty,
    output wire             full
);
    // clog2 helper
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

    // Storage and pointers
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [AW-1:0]    wptr, rptr;
    reg [AW:0]      count;        // number of words in MEM (not including dout)

    // Occupancy includes the output register when valid
    wire [AW:0]     occupancy = count + dout_valid;

    assign empty = (occupancy == 0);
    assign full  = (occupancy == DEPTH);

    // Handshake decisions based on current state (pre-update)
    wire pop_accept   = pop  && dout_valid;
    wire push_accept  = push && (occupancy < DEPTH);

    // If output becomes (or is) empty, decide how to fill it:
    // - refill_mem: take a word from MEM (count > 0)
    // - bypass_fill: take the current DIN directly (count == 0 and we accept a push)
    wire need_refill  = (!dout_valid) || pop_accept;
    wire refill_mem   = need_refill && (count > 0);
    wire bypass_fill  = need_refill && (count == 0) && push_accept;

    // Write to memory only if we are not bypassing into dout
    wire mem_write    = push_accept && !bypass_fill;

    // Next-state signals
    reg              dout_valid_n;
    reg [WIDTH-1:0]  dout_n;
    reg [AW-1:0]     wptr_n, rptr_n;
    reg [AW:0]       count_n;

    always @(*) begin
        // Default: hold state
        dout_n       = dout;
        dout_valid_n = dout_valid;
        wptr_n       = wptr;
        rptr_n       = rptr;
        count_n      = count;

        // Bookkeeping for memory write (advance wptr/count if we will write to MEM)
        if (mem_write) begin
            wptr_n  = wptr + 1'b1;
            count_n = count + 1'b1;
        end

        // If we consumed the output, mark it empty
        if (pop_accept) begin
            dout_valid_n = 1'b0;
        end

        // Refill the output when needed
        if (refill_mem) begin
            // Take a word from MEM (pre-existing data)
            dout_n       = mem[rptr];
            dout_valid_n = 1'b1;
            rptr_n       = rptr + 1'b1;
            count_n      = count_n - 1'b1;
        end else if (bypass_fill) begin
            // First push case: bypass din directly to dout
            dout_n       = din;
            dout_valid_n = 1'b1;
            // No MEM read or pointer changes here; mem_write was suppressed
        end
    end

    // Sequential updates and actual MEM write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr       <= {AW{1'b0}};
            rptr       <= {AW{1'b0}};
            count      <= {(AW+1){1'b0}};
            dout       <= {WIDTH{1'b0}};
            dout_valid <= 1'b0;
        end else begin
            // Perform memory write at current wptr if requested
            if (mem_write) begin
                mem[wptr] <= din;
            end

            // Commit next-state
            wptr       <= wptr_n;
            rptr       <= rptr_n;
            count      <= count_n;
            dout       <= dout_n;
            dout_valid <= dout_valid_n;
        end
    end
endmodule


// Notes:

// On the very first push (with an empty FIFO), the word is driven directly to dout in the same cycle and is not written to memory, avoiding pointer ambiguity.
// When both pop and push occur on the same cycle:
// If there’s pre-existing data (count > 0), the output refills from memory and the pushed word is written into memory.
// If there’s no pre-existing data (count == 0), the output refills via bypass from din and the pushed word is not written to memory (no duplication).


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
// Summary of the behavioral change:

// When OE# and RD# are asserted low, the BFM now drives the data bus in the same cycle using the FWFT RX FIFO’s dout. The pop (consume) happens at 
// the clock edge, and the next word is pre-fetched automatically so subsequent reads can continue back-to-back with one word per cycle. If you need 
// this behavior for FT245 (single-channel) as well, the same FWFT approach applies.
`resetall
