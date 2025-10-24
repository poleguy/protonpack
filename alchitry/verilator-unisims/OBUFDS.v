`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
/* verilator lint_off UNUSEDPARAM */ /* Because this is a dummy for sim */
module OBUFDS (O, OB, I);

    parameter CAPACITANCE = "DONT_CARE";
    parameter IOSTANDARD = "DEFAULT";
    parameter SLEW = "SLOW";

    output O, OB;

    input  I;
   assign O=I;
   assign OB =!I;

endmodule
`resetall
