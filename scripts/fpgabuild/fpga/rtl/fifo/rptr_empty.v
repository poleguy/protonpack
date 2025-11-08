module rptr_empty #(parameter ADDRSIZE = 4) (
    output reg rempty,
    output [ADDRSIZE-1:0] raddr,
    output reg [ADDRSIZE :0] rptr,
    input [ADDRSIZE :0] rq2_wptr,
    input rinc, rclk, rrst_n,
    output reg [ADDRSIZE:0] rdepth // rclk domain
);

 reg [ADDRSIZE:0] rbin;
 wire [ADDRSIZE:0] wbin;
 wire [ADDRSIZE:0] rgraynext, rbinnext;

 initial begin
     rbin=0;
     rptr=0;
     rempty=0;
     rdepth=0;
 end

 //-------------------
 // GRAYSTYLE2 pointer
 //-------------------
 //
 //always @(posedge rclk or negedge rrst_n) make reset sync
 always @(posedge rclk)
     if (!rrst_n) 
         {rbin, rptr} <= 0;
     else 
         {rbin, rptr} <= {rbinnext, rgraynext};

 // Memory read-address pointer (okay to use binary to address memory)
 assign raddr = rbin[ADDRSIZE-1:0];
 assign rbinnext = rbin + (rinc & ~rempty);
 assign rgraynext = (rbinnext>>1) ^ rbinnext;


 //---------------------------------------------------------------
 // FIFO empty when the next rptr == synchronized wptr or on reset
 //---------------------------------------------------------------
 assign rempty_val = (rgraynext == rq2_wptr);

 //always @(posedge rclk or negedge rrst_n) make reset sync
 always @(posedge rclk)
     if (!rrst_n) 
         rempty <= 1'b1;
     else 
         rempty <= rempty_val;

 // convert from gray code to binary count
 // B(31) <= G(31)
 // B(30) <= B(31) xor G(30)
 // B(29) <= B(30) xor G(29)
 // ....
 //
 genvar i;
 generate 
     assign wbin[ADDRSIZE]=rq2_wptr[ADDRSIZE];
     for(i=ADDRSIZE-1; i>=0; i=i-1)
         assign wbin[i] = wbin[i+1] ^ rq2_wptr[i];
 endgenerate

 always @(posedge rclk)
     rdepth <= wbin - rbin;

endmodule
