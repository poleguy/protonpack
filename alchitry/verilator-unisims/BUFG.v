`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
module BUFG (output O, input I);
   assign O=I;
endmodule
`resetall
