// 8b10b encoder
//-------------------------------------------------
// pack_10x_11byte.v
//--------------------------------------------------
//
// Copyright 2025 Shure Incorporated
// CONFIDENTIAL AND PROPRIETARY TO SHURE
//
//--------------------------------------------------
// packs input data one byte at a time into output data
// fills all idle time with k characters
// spits out a data byte 8 out of every 10 clocks
// to allow space for 8b/10b coding
//
// hard coded to work with 11 byte data packets to match portable telemetry
//--------------------------------------------------
// see version control for rev info
//--------------------------------------------------

`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections


module pack_10x_11byte(
    input clk,
    input valid_in,
    input [11*8-1:0] data_in,
    output reg k_out,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg busy
);

    reg [11*8-1:0] r_data_in = 0;
    reg [7:0] r_data_out = 0;
    reg r_k_out = 0;
    reg r_busy = 0;
    reg r_valid_out = 0;
    reg r1_valid_out = 0;
    reg [3:0] r_cnt = 4'hf;
    reg [3:0] r_skip_cnt = 0;
    wire [31:0] crc;
    reg [31:0] r_crc = 0;
    reg [31:0] r_crc_data_in = 0;
   
    always @(posedge clk) begin
        if (r_cnt == 4'h0) begin
            r_data_out <= r_data_in[7:0];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h1) begin
            r_data_out <= r_data_in[15:8];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h2) begin
            r_data_out <= r_data_in[23:16];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h3) begin
            r_data_out <= r_data_in[31:24];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h4) begin
            r_data_out <= r_data_in[39:32];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h5) begin
            r_data_out <= r_data_in[47:40];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h6) begin
            r_data_out <= r_data_in[55:48];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h7) begin
            r_data_out <= r_data_in[63:56];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h8) begin
            r_data_out <= r_data_in[71:64];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'h9) begin
            r_data_out <= r_data_in[79:72];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'ha) begin
            r_data_out <= r_data_in[87:80];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'hb) begin
            r_data_out <= crc[7:0];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'hc) begin
            r_data_out <= crc[15:8];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'hd) begin
            r_data_out <= crc[23:16];
            r_k_out <= 0;
            r_busy <= 1;
        end else if (r_cnt == 4'he) begin
            r_data_out <= crc[31:24];
            r_k_out <= 0;
            r_busy <= 1;
        end else begin
            r_k_out <= 1;    
            r_data_out <= 8'hBC;
            r_busy <= 0;
        end
    end

    always @(posedge clk) begin
        if (valid_in == 1) begin
            r_cnt <= 4'h0;
        end else if (r_cnt > 4'he) begin
            r_cnt <= 4'hf; 
        end else if (r_skip_cnt < 4'h8) begin
            r_cnt <= r_cnt + 1; 
        end
    end

    always @(posedge clk) begin
        if (r_skip_cnt == 4'h9) begin
            r_skip_cnt <= 0;
            r_valid_out <= 1;
        end else if (r_skip_cnt < 4'h7) begin
            r_skip_cnt <= r_skip_cnt + 1;
            r_valid_out <= 1;
        end else begin
            r_skip_cnt <= r_skip_cnt + 1;
            r_valid_out <= 0;
        end
    end

    always @(posedge clk) begin
        if (valid_in == 1) begin
            r_data_in <= data_in;
        end
    end

    always @(posedge clk) begin
        r1_valid_out <= r_valid_out;
    end

    always @(posedge clk) begin
        if (r_cnt == 4'h0) begin
            r_crc_data_in <= r_data_out;
            r_crc <= 0;
        end else if (r_cnt <= 4'ha) begin
            r_crc_data_in <= r_data_out;
            r_crc <= crc_wire;
        end else begin
            r_crc_data_in <= r_crc_data_in;
            r_crc <= r_crc;
        end
    end

    // Entity for CRC calculation (Note this should be defined elsewhere in the actual implementation)

    assign crc = crc_calc(r_crc, r_crc_data_in); // Replace with actual function or module

    // Outputs
    //always @(posedge clk) begin
   assign data_out = r_data_out;
   assign k_out = r_k_out;
   assign busy = r_busy;
   assign valid_out = r1_valid_out;
    //end

endmodule

function [31:0] crc_calc(input [31:0] crc_in, input [7:0] data);
    crc_calc[0] = crc_in[2] ^ crc_in[8] ^ data[2];
    crc_calc[1] = crc_in[0] ^ crc_in[3] ^ crc_in[9] ^ data[0] ^ data[3];
    crc_calc[2] = crc_in[0] ^ crc_in[1] ^ crc_in[4] ^ crc_in[10] ^ data[0] ^ data[1] ^ data[4];
    crc_calc[3] = crc_in[1] ^ crc_in[2] ^ crc_in[5] ^ crc_in[11] ^ data[1] ^ data[2] ^ data[5];
    crc_calc[4] = crc_in[0] ^ crc_in[2] ^ crc_in[3] ^ crc_in[6] ^ crc_in[12] ^ data[0] ^ data[2] ^ data[3] ^ data[6];
    crc_calc[5] = crc_in[1] ^ crc_in[3] ^ crc_in[4] ^ crc_in[7] ^ crc_in[13] ^ data[1] ^ data[3] ^ data[4] ^ data[7];
    crc_calc[6] = crc_in[4] ^ crc_in[5] ^ crc_in[14] ^ data[4] ^ data[5];
    crc_calc[7] = crc_in[0] ^ crc_in[5] ^ crc_in[6] ^ crc_in[15] ^ data[0] ^ data[5] ^ data[6];
    crc_calc[8] = crc_in[1] ^ crc_in[6] ^ crc_in[7] ^ crc_in[16] ^ data[1] ^ data[6] ^ data[7];
    crc_calc[9] = crc_in[7] ^ crc_in[17] ^ data[7];
    crc_calc[10] = crc_in[2] ^ crc_in[18] ^ data[2];
    crc_calc[11] = crc_in[3] ^ crc_in[19] ^ data[3];
    crc_calc[12] = crc_in[0] ^ crc_in[4] ^ crc_in[20] ^ data[0] ^ data[4];
    crc_calc[13] = crc_in[0] ^ crc_in[1] ^ crc_in[5] ^ crc_in[21] ^ data[0] ^ data[1] ^ data[5];
    crc_calc[14] = crc_in[1] ^ crc_in[2] ^ crc_in[6] ^ crc_in[22] ^ data[1] ^ data[2] ^ data[6];
    crc_calc[15] = crc_in[2] ^ crc_in[3] ^ crc_in[7] ^ crc_in[23] ^ data[2] ^ data[3] ^ data[7];
    crc_calc[16] = crc_in[0] ^ crc_in[2] ^ crc_in[3] ^ crc_in[4] ^ crc_in[24] ^ data[0] ^ data[2] ^ data[3] ^ data[4];
    crc_calc[17] = crc_in[0] ^ crc_in[1] ^ crc_in[3] ^ crc_in[4] ^ crc_in[5] ^ crc_in[25] ^ data[0] ^ data[1] ^ data[3] ^ data[4] ^ data[5];
    crc_calc[18] = crc_in[0] ^ crc_in[1] ^ crc_in[2] ^ crc_in[4] ^ crc_in[5] ^ crc_in[6] ^ crc_in[26] ^ data[0] ^ data[1] ^ data[2] ^ data[4] ^ data[5] ^ data[6];
    crc_calc[19] = crc_in[1] ^ crc_in[2] ^ crc_in[3] ^ crc_in[5] ^ crc_in[6] ^ crc_in[7] ^ crc_in[27] ^ data[1] ^ data[2] ^ data[3] ^ data[5] ^ data[6] ^ data[7];
    crc_calc[20] = crc_in[3] ^ crc_in[4] ^ crc_in[6] ^ crc_in[7] ^ crc_in[28] ^ data[3] ^ data[4] ^ data[6] ^ data[7];
    crc_calc[21] = crc_in[2] ^ crc_in[4] ^ crc_in[5] ^ crc_in[7] ^ crc_in[29] ^ data[2] ^ data[4] ^ data[5] ^ data[7];
    crc_calc[22] = crc_in[2] ^ crc_in[3] ^ crc_in[5] ^ crc_in[6] ^ crc_in[30] ^ data[2] ^ data[3] ^ data[5] ^ data[6];
    crc_calc[23] = crc_in[3] ^ crc_in[4] ^ crc_in[6] ^ crc_in[7] ^ crc_in[31] ^ data[3] ^ data[4] ^ data[6] ^ data[7];
    crc_calc[24] = crc_in[0] ^ crc_in[2] ^ crc_in[4] ^ crc_in[5] ^ crc_in[7] ^ data[0] ^ data[2] ^ data[4] ^ data[5] ^ data[7];
    crc_calc[25] = crc_in[0] ^ crc_in[1] ^ crc_in[2] ^ crc_in[3] ^ crc_in[5] ^ crc_in[6] ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[5] ^ data[6];
    crc_calc[26] = crc_in[0] ^ crc_in[1] ^ crc_in[2] ^ crc_in[3] ^ crc_in[4] ^ crc_in[6] ^ crc_in[7] ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[6] ^ data[7];
    crc_calc[27] = crc_in[1] ^ crc_in[3] ^ crc_in[4] ^ crc_in[5] ^ crc_in[7] ^ data[1] ^ data[3] ^ data[4] ^ data[5] ^ data[7];
    crc_calc[28] = crc_in[0] ^ crc_in[4] ^ crc_in[5] ^ crc_in[6] ^ data[0] ^ data[4] ^ data[5] ^ data[6];
    crc_calc[29] = crc_in[0] ^ crc_in[1] ^ crc_in[5] ^ crc_in[6] ^ crc_in[7] ^ data[0] ^ data[1] ^ data[5] ^ data[6] ^ data[7];
    crc_calc[30] = crc_in[0] ^ crc_in[1] ^ crc_in[6] ^ crc_in[7] ^ data[0] ^ data[1] ^ data[6] ^ data[7];
    crc_calc[31] = crc_in[1] ^ crc_in[7] ^ data[1] ^ data[7];
endfunction

`resetall