`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
/* verilator lint_off UNOPTFLAT */
/******************************************************************************

   The MIT License (MIT)

   Copyright (c) 2025 Alchitry

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

   *****************************************************************************

   This is an asynchronous fifo. That means it has two independently clocked
   interfaces that allow you to write data from one clock domain and read
   it from another.

   This is a first-word-fall-through fifo meaning that dout is valid whenever
   empty is 0. If you want to perform a read, simply check if empty is 0 and
   if it is read the value of dout and set rget high to advance to the next
   value.

   SYNC_STAGES is used to set the number of chained dffs used when crossing
   clock domains. 3 is usually a good default, but fewer can be used when latency
   is a priority over reliability.
*******************************************************************************/

module async_fifo #(
    parameter WIDTH       = 8,  // Size of the data
    parameter ENTRIES     = 16, // Must be power of 2
    parameter SYNC_STAGES = 3   // Number of synchronizing stages (>=2)
)(
    input  wire                 wclk,   // write clock
    input  wire                 wrst,   // write reset
    input  wire [WIDTH-1:0]      din,    // write data
    input  wire                 wput,   // write flag (1 = write)
    output wire                 full,   // full flag (1 = full)

    input  wire                 rclk,   // read clock
    input  wire                 rrst,   // read reset
    output wire [WIDTH-1:0]      dout,   // read data
    input  wire                 rget,   // data read flag (1 = get next entry)
    output wire                 empty   // empty flag (1 = empty)
);

    localparam ADDR_SIZE = $clog2(ENTRIES);

    // ------------------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------------------
    reg  [ADDR_SIZE:0] waddr_bin, raddr_bin;
    reg  [ADDR_SIZE:0] waddr_bin_next, raddr_bin_next;

    reg  [ADDR_SIZE:0] waddr_gray, raddr_gray;
    reg  [ADDR_SIZE:0] wnext_gray, rnext_gray;

    // Synchronizers for cross-domain pointers
    (* ASYNC_REG = "TRUE" *) reg [ADDR_SIZE:0] wsync   [0:SYNC_STAGES-1];
    (* ASYNC_REG = "TRUE" *) reg [ADDR_SIZE:0] rsync   [0:SYNC_STAGES-1];

    // Dual-port memory
    reg [WIDTH-1:0] mem [0:ENTRIES-1];

    reg [WIDTH-1:0] dout_reg;
    assign dout = dout_reg;

    // Ready flags
    wire wrdy, rrdy;

    // ------------------------------------------------------------------------
    // WRITE CLOCK DOMAIN
    // ------------------------------------------------------------------------
    always @(posedge wclk or posedge wrst) begin
        if (wrst) begin
            waddr_bin  <= 0;
            waddr_gray <= 0;
        end else begin
            if (wput && wrdy) begin
                waddr_bin <= waddr_bin + 1;
            end
            waddr_gray <= (waddr_bin >> 1) ^ waddr_bin;
        end
    end

    // Write memory
    always @(posedge wclk) begin
        if (wput && wrdy)
            mem[waddr_bin[ADDR_SIZE-1:0]] <= din;
    end

    // ------------------------------------------------------------------------
    // READ CLOCK DOMAIN
    // ------------------------------------------------------------------------
    always @(posedge rclk or posedge rrst) begin
        if (rrst) begin
            raddr_bin  <= 0;
            raddr_gray <= 0;
        end else begin
            if (rget && rrdy) begin
                raddr_bin <= raddr_bin + 1;
            end
            raddr_gray <= (raddr_bin >> 1) ^ raddr_bin;
        end
    end

    // Read data (first-word-fall-through)
    always @(posedge rclk) begin
        dout_reg <= mem[raddr_bin[ADDR_SIZE-1:0]];
    end

    // ------------------------------------------------------------------------
    // CROSS-DOMAIN SYNCHRONIZATION
    // ------------------------------------------------------------------------
    integer i;
    always @(posedge wclk or posedge wrst) begin
        if (wrst)
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                wsync[i] <= 0;
        else begin
            wsync[0] <= raddr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                wsync[i] <= wsync[i-1];
        end
    end

    always @(posedge rclk or posedge rrst) begin
        if (rrst)
            for (i = 0; i < SYNC_STAGES; i = i + 1)
                rsync[i] <= 0;
        else begin
            rsync[0] <= waddr_gray;
            for (i = 1; i < SYNC_STAGES; i = i + 1)
                rsync[i] <= rsync[i-1];
        end
    end

    // ------------------------------------------------------------------------
    // FULL / EMPTY DETECTION
    // ------------------------------------------------------------------------
    wire [ADDR_SIZE:0] wsync_rgray = wsync[SYNC_STAGES-1];
    wire [ADDR_SIZE:0] rsync_wgray = rsync[SYNC_STAGES-1];

    // Next write and read gray pointers
    assign waddr_bin_next = waddr_bin + 1;
    assign wnext_gray     = (waddr_bin_next >> 1) ^ waddr_bin_next;
    assign raddr_bin_next = raddr_bin + 1;
    assign rnext_gray     = (raddr_bin_next >> 1) ^ raddr_bin_next;

    // Write ready unless next write equals synchronized read (full)
    assign wrdy = (wnext_gray != {~wsync_rgray[ADDR_SIZE:ADDR_SIZE-1], wsync_rgray[ADDR_SIZE-2:0]});

    // Read ready unless read == synchronized write (empty)
    assign rrdy = (raddr_gray != rsync_wgray);

    assign full  = ~wrdy;
    assign empty = ~rrdy;

endmodule
`resetall
/* verilator lint_on UNOPTFLAT */
