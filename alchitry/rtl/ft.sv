
// -----------------------------------------------------------------------------
// MIT License (MIT)
// Copyright (c) 2025 Alchitry
//
// This module interfaces with FTDI FT600/FT601 (Ft/Ft+).
// BUS_WIDTH: 16 (FT600) or 32 (FT601).
// TX_BUFFER and RX_BUFFER should be powers of two.
// PRIORITY_TX: 0 = RX priority, 1 = TX priority.
// PREEMPT: 1 enables preemption of ongoing non-priority transfers.
//
// Fixed for pure Verilog, registered control signals, and robust FIFO strobes.


`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections


// -----------------------------------------------------------------------------
/* verilator lint_off UNOPTFLAT */
module ft #(
    parameter integer BUS_WIDTH   = 16,  // 16 = FT600, 32 = FT601
    parameter integer TX_BUFFER   = 2048,  // depth of TX FIFO (power of 2)
    parameter integer RX_BUFFER   = 2048,  // depth of RX FIFO (power of 2)
    parameter integer PRIORITY_TX = 0,   // 0 = RX priority, 1 = TX priority
    parameter integer PREEMPT     = 0    // 0 = no preemption, 1 = allow
)(
    input  wire                         clk,        // system clock
    input  wire                         rst,        // async reset (active high)

    // FTDI
    input  wire                         ft_clk,     // FTDI clock
    input  wire                         ft_rxf,     // low when FTDI has data for us (RX FIFO not empty)
    input  wire                         ft_txe,     // low when FTDI can accept data (TX FIFO not full)
    inout  wire [BUS_WIDTH-1:0]         ft_data,    // data bus
    inout  wire [(BUS_WIDTH/8)-1:0]     ft_be,      // byte enables (1 = valid byte)
    output reg                          ft_rd,      // 0 = read active
    output reg                          ft_wr,      // 0 = write active
    output reg                          ft_oe,      // 0 = FTDI drives bus, 1 = FPGA drives bus

    // Write interface (to FTDI)
    input  wire [BUS_WIDTH-1:0]         ui_din,       // data in
    input  wire [(BUS_WIDTH/8)-1:0]     ui_din_be,    // byte enables for din
    input  wire                         ui_din_valid, // 1 = din valid
    output wire                         ui_din_full,  // 1 = TX buffer full

    // Read interface (from FTDI)
    output wire [BUS_WIDTH-1:0]         ui_dout,      // data out
    output wire [(BUS_WIDTH/8)-1:0]     ui_dout_be,   // byte enables for dout
    output wire                         ui_dout_empty,// 1 = RX buffer empty
    input  wire                         ui_dout_get   // 1 = consumer read ui_dout
);

    // -------------------------------------------------------------------------
    // Parameter validation (simulation-time)
    // -------------------------------------------------------------------------
    initial begin
        if (BUS_WIDTH != 16 && BUS_WIDTH != 32)
            $fatal(1, "BUS_WIDTH must be 16 or 32");
        if ((TX_BUFFER & (TX_BUFFER-1)) != 0)
            $fatal(1, "TX_BUFFER must be a power of 2");
        if ((RX_BUFFER & (RX_BUFFER-1)) != 0)
            $fatal(1, "RX_BUFFER must be a power of 2");
        if (PRIORITY_TX != 0 && PRIORITY_TX != 1)
            $fatal(1, "PRIORITY_TX must be 0 or 1");
        if (PREEMPT != 0 && PREEMPT != 1)
            $fatal(1, "PREEMPT must be 0 or 1");
    end

    // -------------------------------------------------------------------------
    // Local parameters and signals
    // -------------------------------------------------------------------------
    localparam integer BE_WIDTH   = (BUS_WIDTH/8);
    localparam integer FIFO_WIDTH = BUS_WIDTH + BE_WIDTH;

    // FSM states
    localparam [1:0] S_IDLE       = 2'd0;
    localparam [1:0] S_BUS_SWITCH = 2'd1;
    localparam [1:0] S_READ       = 2'd2;
    localparam [1:0] S_WRITE      = 2'd3;

    reg  [1:0] state, next_state;

    // Write FIFO (UI clk -> FT clk)
    wire                    write_fifo_full;   // write-side (clk) full
    wire                    write_fifo_empty;  // read-side  (ft_clk) empty
    wire [FIFO_WIDTH-1:0]   write_fifo_dout;   // read-side data (ft_clk)
    reg                     write_fifo_rget;  // read-side get (ft_clk)

    // Read FIFO (FT clk -> UI clk)
    wire                    read_fifo_full;    // write-side (ft_clk) full
    wire                    read_fifo_empty;   // read-side  (clk) empty
    wire [FIFO_WIDTH-1:0]   read_fifo_dout;    // read-side data (clk)
    reg                     read_fifo_wput;    // write-side put (ft_clk)


    // Convenience: capability checks (ft_clk domain)
    wire can_write = (~ft_txe) && (~write_fifo_empty);
    wire can_read  = (~ft_rxf) && (~read_fifo_full);
    reg [1:0] preferred_state;

    // -------------------------------------------------------------------------
    // Asynchronous FIFO instances
    // -------------------------------------------------------------------------
    // TX path: UI writes, FT reads
    async_fifo #(
        .WIDTH  (FIFO_WIDTH),
        .ENTRIES(TX_BUFFER)
    ) write_fifo (
        .rclk   (ft_clk),
        .rrst   (rst),
        .rget   (write_fifo_rget),
        .dout   (write_fifo_dout),
        .empty  (write_fifo_empty),

        .wclk   (clk),
        .wrst   (rst),
        .wput   (ui_din_valid),
        .din    ({ui_din_be, ui_din}),
        .full   (write_fifo_full)
    );

    // RX path: FT writes, UI reads
    async_fifo #(
        .WIDTH  (FIFO_WIDTH),
        .ENTRIES(RX_BUFFER)
    ) read_fifo (
        .rclk   (clk),
        .rrst   (rst),
        .rget   (ui_dout_get),
        .dout   (read_fifo_dout),
        .empty  (read_fifo_empty),

        .wclk   (ft_clk),
        .wrst   (rst),
        .wput   (read_fifo_wput),
        .din    ({ft_be, ft_data}),
        .full   (read_fifo_full)
    );

    // -------------------------------------------------------------------------
    // UI side connections (clk domain)
    // -------------------------------------------------------------------------
    assign ui_din_full   = write_fifo_full;

    assign ui_dout       = read_fifo_dout[BUS_WIDTH-1:0];
    assign ui_dout_be    = read_fifo_dout[FIFO_WIDTH-1:BUS_WIDTH];
    assign ui_dout_empty = read_fifo_empty;

    // -------------------------------------------------------------------------
    // FT data/BE tri-state control
    // FPGA drives bus only when ft_oe == 1 (write mode or blocking reads)
    // -------------------------------------------------------------------------
    assign ft_data = ft_oe
                   ? write_fifo_dout[BUS_WIDTH-1:0]
                   : {BUS_WIDTH{1'bz}};

    assign ft_be   = ft_oe
                   ? write_fifo_dout[FIFO_WIDTH-1:BUS_WIDTH]
                   : {BE_WIDTH{1'bz}};

    // -------------------------------------------------------------------------
    // FSM and FT control logic (ft_clk domain)
    // -------------------------------------------------------------------------
    always @(posedge ft_clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @* begin
        // Defaults (idle/disabled)
        next_state           = state;
        ft_oe              = 1'b1;  // 1 = FPGA drives, 0 = FTDI drives
        ft_rd              = 1'b1;  // 0 = reading
        ft_wr              = 1'b1;  // 0 = writing
        write_fifo_rget    = 1'b0;
        read_fifo_wput     = 1'b0;

        // Preferred next state based on capability and priority

        preferred_state = S_IDLE;

        if (can_write && (PRIORITY_TX || !can_read)) begin
            preferred_state = S_WRITE;
        end
        if (can_read && ((!PRIORITY_TX) || !can_write)) begin
            preferred_state = S_BUS_SWITCH;
        end

        case (state)
            S_IDLE: begin
                next_state = preferred_state;
            end

            S_BUS_SWITCH: begin
                // Per FTDI docs, drive OE low for a single cycle when switching to read
                ft_oe      = 1'b0;
                next_state   = S_READ;
            end

            S_READ: begin
                // Use RX FIFO full flag to gate FT OE/RD (0 means we accept data)
                ft_oe          = read_fifo_full;             // 0 => FTDI drives bus

                // immediately stop read if no data is available (ft_rxf == 1)
                ft_rd          = read_fifo_full || ft_rxf;             // 0 => read active
                read_fifo_wput = (~ft_rxf) && (~read_fifo_full);

                // Exit read if FTDI has no data, RX FIFO full,
                // or preempt by TX if enabled and preferred is WRITE
                if (ft_rxf || read_fifo_full ||
                    (PREEMPT && (preferred_state == S_WRITE))) begin
                    next_state = preferred_state;
                end else begin
                    next_state = S_READ;
                end
            end

            S_WRITE: begin
                // Use TX FIFO empty flag to gate FT WR (0 means we present valid data)
                ft_wr           = write_fifo_empty;           // 0 => write active
                write_fifo_rget = (~ft_txe) && (~write_fifo_empty);

                // Exit write if FTDI can't accept, TX FIFO empty,
                // or preempt by RX if enabled and preferred is BUS_SWITCH
                if (ft_txe || write_fifo_empty ||
                    (PREEMPT && (preferred_state == S_BUS_SWITCH))) begin
                    next_state = preferred_state;
                end else begin
                    next_state = S_WRITE;
                end
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

endmodule
/* verilator lint_on UNOPTFLAT */
`resetall
