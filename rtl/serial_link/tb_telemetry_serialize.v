// Company: Shure, Inc.
// Engineer: Nicholas Dietz
// Revision : bitbucket
//
// Description: Top level testbench instantiation file
// to simulate telemetry_serialize connected to a receiver
//

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections

module tb_telemetry_serialize;

  reg clk_100 = 0;
  reg clk_200 = 0;
  reg clk_400 = 0;

  // INPUT INITIALIZATION - Can initialize VHDL inputs to 0 OK, but for Verilog telem_mobile_ac701
  // this is not working. So we have to have signals here and cocotb drive these signals versus
  // going 1 level down into telem_mobile_ac701.

  initial
  begin
    forever
    begin
      #5.000 clk_100 = ~clk_100;
    end
  end

  initial
  begin
    forever
    begin
      #2.500 clk_200 = ~clk_200;
    end
  end

  initial
  begin
    forever
    begin
      #1.250 clk_400 = ~clk_400;
    end
  end

  // cocotb will drive other inputs, eg. packet, packet_valid
  // list all ports to avoid cvc warning:
  // WARN** [531] telemetry_serialize_inst(telemetry_serialize) explicit connection list fewer ports 7 connected than type's 8

  telemetry_serialize telemetry_serialize_inst (
             .clk(clk_100),
             .clk4x(clk_400),
             .reset_clk(),
             .packet(),
             .packet_valid(),
             .serializer_ready(),
             .O(),
             .OB()

           );

// packet and packet_valid will be copied back and forth using cocotb
  unpack_telemetry unpack_telemetry_inst (
    .clk(clk_200),
    // using valid from previous block, so first input will be invalid and missed
    .k_in(),
    .data_in(),
    .valid_in(),
    .data_out(),
    .valid_out(),
    .bad_packet()
  );

endmodule

`resetall