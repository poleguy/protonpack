`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2025 03:47:31 PM
// Design Name: 
// Module Name: blink
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module blink(
    input wire clk,
    input wire inny,
    output reg outy
    );
    
     // Parameters to calculate clock division factor
    // 100 MHz is 100,000,000 cycles per second, to get 1 second period we divide by 100,000,000
    parameter CLK_DIV = 100_000_000;

    reg [31:0] counter;  // 32-bit counter for clock division
    reg one_second_clock;  // 1 Hz signal generated

    // Clock divider process
    always @(posedge clk) begin
        if (counter == CLK_DIV - 1) begin
            counter <= 0;
            one_second_clock <= ~one_second_clock;
        end else begin
            counter <= counter + 1;
        end
    end

    // Toggle output 'outy' process
    always @(posedge clk) begin
        outy <= inny ? ~one_second_clock : one_second_clock;
    end
    
endmodule


