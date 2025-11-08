// tick generator to produce a (power of two) slow prescaler tick for debouncers, etc.
`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module tick_gen #(
        parameter COUNTER_SIZE = 22  // 22 -> ~100 ms at 32 MHz (2^22 / 32e6 ≈ 0.104 s)
    )(
        input  wire clk,     // input clock
        output reg prescaler // to use a shared external prescaler counter
    );

    // Counter to measure stable time; width is COUNTER_SIZE+1
    reg  [COUNTER_SIZE:0] counter_out;

    initial begin
        counter_out = { (COUNTER_SIZE+1){1'b0} };
    end

    always @(posedge clk) begin
        counter_out <= counter_out + 1'b1;
    end

    always @(posedge clk) begin

        // version register
        if (counter_out == 0) begin
            prescaler = 1'b1;
        end
        else begin
            prescaler = 1'b0;
        end
    end

endmodule

`resetall
