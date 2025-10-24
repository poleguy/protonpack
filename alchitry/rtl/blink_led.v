`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
module blink_led (
    input wire clk_128M,         // 128MHz input clock
    output reg led          // Output to control LED
);

    // Calculate the required count to achieve a 1Hz signal
    localparam COUNT_MAX = 128_000_000 / 2 - 1; // Half cycle count
    reg [26:0] counter;    // 27 bits to store up to `64_000_000`

    always @(posedge clk_128M) begin
        if (counter == COUNT_MAX) begin
            counter <= 0;
            led <= ~led; // Toggle the LED
        end else begin
            counter <= counter + 1;
        end
    end

endmodule
`resetall
