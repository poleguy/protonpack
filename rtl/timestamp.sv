// create a timestamp that can be used to synchronize the incoming serial data stream with the RTC clock on the raspberry pi host.
// we'll try to make this work by having the raspberry pi host sample this register to determine the offset from real time?
// or should we pull this?
// should we accept a pps input?n

// if the PC periodically reads this value and assigns an RTC time value to it, the other values can be interpolated in software.
// e.g. the
// maybe 8 bits of timestamp can come from the DUT. That will wrap around every 2 usec.
// that needs to be enough to remove any fifo jitter.
// since we recover the clock, we can use the recovered clock to extend that counter
// this will take those 8 bits and simply add them to our 32 bits.
// at 32 bits at 128MHz this will wrap around once every 34 seconds.

// the timestamp will increase synchronously with the DUT clock timebase
// it can thus be added directly to the 8-bit timestamps from the dut.
// the timestamp_in from the serial stream can be used to detect wrap around.


`timescale 1ns / 1ps
`default_nettype none  //do not use implicit wire for port connections


module timestamp (
        input wire clk_128M,
        input wire gt_clk_edge_128M,  // once per DUT recovered clock edge at 25.6 MHz
        input wire [7:0] timestamp_in,  // from serial stream
        input wire timestamp_valid,  // from serial stream
        output wire offset_adjust, // marks offset adjustment for debug
        output wire [31:0] timestamp_count  // count in 128MHz clocks
    );

    reg [31:0] r_timestamp_counter = 32'h0;
    reg [31:0] r_timestamp_count = 32'h0;
    reg [ 7:0] r_timestamp_offset = 8'h0;
    reg r_offset_adjust = 1'b0;

    // synchronize to timestamp_in continuously to find the shortest delay
    //
    always @(posedge clk_128M) begin
        if (r_timestamp_count == 32'b0) begin
            // gradually and occasionally bump the offset back up so that it doesn't get stuck
            r_timestamp_offset <= r_timestamp_counter[7:0] + 8'h01;
        end
        else if (r_timestamp_offset == 8'hff) begin
            r_timestamp_offset <= 8'hff;
        end
    end

    always @(posedge clk_128M) begin
        if (timestamp_valid == 1'b1) begin
            if (r_timestamp_offset < r_timestamp_counter[7:0] - timestamp_in) begin
                r_timestamp_offset <= r_timestamp_counter[7:0] - timestamp_in;
                r_offset_adjust <= 1'b1;
            end
            else begin
                r_offset_adjust <= 1'b0;
            end
        end
    end

    assign offset_adjust = r_offset_adjust;

    always @(posedge clk_128M) begin
        if (gt_clk_edge_128M == 1'b1) begin
            r_timestamp_counter <= r_timestamp_counter + 32'h1;
        end

        r_timestamp_count <= r_timestamp_counter + {24'b0, r_timestamp_offset};
    end

    assign timestamp_count = r_timestamp_count;

endmodule

`resetall
