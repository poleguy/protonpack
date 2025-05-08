//ila_logger

//////////////////////////////////////////////////
// log a group of signals in a single clock domain with an enable
// allow reset to restart capture using a magic write
//////////////////////////////////////////////////
`default_nettype none // Do not use implicit wire for port connections

module ila_logger (
    input wire clk_fast,
    input wire valid,
    input wire [31:0] data,
    input wire clk,
    input wire we,
    input wire [7:0] addr,
    output reg [31:0] ram_readback
);

reg [31:0] ram [0:255]; // 256 sequential entries in one small RAM with 32 bits
reg [7:0] ram_addr;
reg [3:0] dev_addr;
reg r_erase;
reg r1_erase;
reg r2_erase;

// cdc
always @(posedge clk_fast) begin
    r1_erase <= r_erase;
    r2_erase <= r1_erase;    
end

always @(posedge clk_fast) begin
    if (r2_erase) begin  // Magic read to start over
        ram_addr <= 0;
    end else begin
        // capture whenever valid
        if (valid && (ram_addr < 10'd255)) begin // Check if any bit in 'we' is high
            
            ram[ram_addr] <= data; // Write data to RAM
            ram_addr <= ram_addr + 1; // Increment address after each write
        end
    end
end

always @(posedge clk) begin
    if (we && (addr == 8'hFF)) begin  // Magic write to start over
        r_erase <= 1;
    end else begin
        r_erase <= 0;
    end
end


always @(posedge clk) begin
    ram_readback <= ram[addr[7:0]][31:0];
end

endmodule

`default_nettype wire // Turn it off
