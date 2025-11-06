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
// Converted from Lucid to Verilog.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module ft #(
    parameter integer BUS_WIDTH   = 16,  // 16 = FT600, 32 = FT601
    parameter integer TX_BUFFER   = 64,  // depth of TX FIFO (power of 2)
    parameter integer RX_BUFFER   = 64,  // depth of RX FIFO (power of 2)
    parameter bit     PRIORITY_TX = 1'b0,// 0 = RX priority, 1 = TX priority
    parameter bit     PREEMPT     = 1'b0 // 0 = no preemption, 1 = allow
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
    reg                     write_fifo_rget;   // read-side get (ft_clk)

    // Read FIFO (FT clk -> UI clk)
    wire                    read_fifo_full;    // write-side (ft_clk) full
    wire                    read_fifo_empty;   // read-side  (clk) empty
    wire [FIFO_WIDTH-1:0]   read_fifo_dout;    // read-side data (clk)
    reg                     read_fifo_wput;    // write-side put (ft_clk)

    logic can_write;
    logic can_read;
    reg [1:0] preferred_state;
    //logic [1:0] preferred_state;

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
    // FT data/BE tri-state control (I/O level)
    // Release bus when reading (BUS_SWITCH or READ)
    // -------------------------------------------------------------------------
    wire reading_bus = (state == S_BUS_SWITCH) || (state == S_READ);

    assign ft_data = reading_bus
                   ? {BUS_WIDTH{1'bz}}
                   : write_fifo_dout[BUS_WIDTH-1:0];

    assign ft_be   = reading_bus
                   ? {BE_WIDTH{1'bz}}
                   : write_fifo_dout[FIFO_WIDTH-1:BUS_WIDTH];

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
        // Defaults
        ft_oe           = 1'b1; // 1 = FPGA drives, 0 = FTDI drives
        ft_rd           = 1'b1; // 0 = reading
        ft_wr           = 1'b1; // 0 = writing
        write_fifo_rget = 1'b0;
        read_fifo_wput  = 1'b0;
        next_state      = state;

        // Capability checks (ft_clk domain flags)
        // can_write: FT can accept data and we have TX data
        // can_read:  FT has data and we have RX space
        can_write = ((~ft_txe) && (~write_fifo_empty));
        can_read  = ((~ft_rxf) && (~read_fifo_full));

        // Preferred next state based on priority
        
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
                next_state = S_READ;
            end

            S_READ: begin
                // Use RX FIFO full flag to gate FT OE/RD (0 means we accept data)
                ft_oe          = read_fifo_full;
                ft_rd          = read_fifo_full;
                read_fifo_wput = ~ft_rxf; // rxf=0 => valid data available

                // Exit read if FTDI has no data, our RX FIFO is full,
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
                ft_wr           = write_fifo_empty;
                write_fifo_rget = ~ft_txe; // txe=0 => FT can accept data

                // Exit write if FTDI can't accept, our TX FIFO empty,
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

`resetall
