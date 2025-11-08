// mpu2; kcpsm2 processor, picoblaze by xilinx

module mpu2(clk,i,interrupt,inport,addr,outport,port_id,read_strobe,write_strobe);

input clk;
input [17:0] i;
input interrupt;
input [7:0] inport;
output [9:0] addr;
output [7:0] outport;
output [7:0] port_id;
output read_strobe;
output write_strobe;

wire clk,interrupt;
wire [17:0] i;
wire [7:0] inport;

wire [7:0] outport,port_id;
reg read_strobe,write_strobe;
reg rbwe,flgwe;
reg intok;
//reg [4:0] data;
wire [9:0] addr;

wire [7:0] sX,sXo,sYo,sXo1;
wire insel,outsel,load;
wire flgchk;
wire retiok,retok,callok,jumpok;
reg clkdiv;

// flags
reg cflag,zflag,intcf,intzf;
wire cin,zin;

// program control
reg [9:0] pc;
reg [3:0] sptr;
wire [9:0] stackout;
reg [9:0] stackoutr,stackout1r,pc1r;
reg intflag;
wire zfgin,cfgin;

// clock divider
initial clkdiv = 0;
always @(posedge clk) begin
	clkdiv <= clkdiv + 1;
end
//rom for combinational logic
//initial data <= 4'b0000;
/*
always @(i[15:12] or clkdiv) begin
//		if (clkdiv)
			case({clkdiv,i[15:13]})
			4'b0000: data = 5'b01100;
			4'b0001: data = 5'b01100;
			4'b0010: data = 5'b11100;
			4'b0011: data = 5'b11100;
			4'b0100: data = 5'b00000;
			4'b0101: data = 5'b00101;
			4'b0110: data = 5'b01100;
			4'b0111: data = 5'b00010;
			4'b1000: data = 5'b01100;
			4'b1001: data = 5'b01100;
			4'b1010: data = 5'b01100;
			4'b1011: data = 5'b01100;
			4'b1100: data = 5'b00000;
			4'b1101: data = 5'b00101;
			4'b1110: data = 5'b01100;
			4'b1111: data = 5'b00010;
			endcase
//		else data = 4'h0;
end
*/
//assign pcwe = clkdiv;
//assign read_strobe = data[0];
//assign write_strobe = data[1];
//assign rbwe = data[2];
//assign flgwe = data[3];
//assign jcsel = data[4];
 
always @(posedge clk) begin
	if (clkdiv&~intok) begin
		read_strobe <= insel;
//		read_strobe <= ~i[15]&~i[14]&~i[13];
	  	write_strobe <= outsel;
//		write_strobe <= ~i[15]&~i[14]&i[13];
//		rbwe <= ~outsel&~jcsel;
		rbwe <= ~i[17]|(~i[14]&~i[13]);
//		flgwe <= ~jcsel&~outsel&~load&~insel;
		flgwe <= (~i[17]|(i[15]&~i[14]))&~load;
	end
	else begin
		read_strobe <= 1'b0;
		write_strobe <= 1'b0;
		rbwe <= 1'b0;
		flgwe <= 1'b0;
	end
end

// interrupt logic
initial intflag = 1'b0;
always @(posedge clk) begin
	if (intok) intflag <= 1'b0;
	else if (clkdiv) begin
		if (i[17]&i[15]&i[14]) begin
			if (i[0]) intflag <= 1'b1;
			else intflag <= 1'b0;
		end
	end
	else intflag <= intflag;
end

always @(posedge clk) begin
	if (intflag&interrupt&~clkdiv) intok <= 1'b1;
	else intok <= 1'b0;
end

// combintorial select signals
assign insel = i[17]&~i[15]&~i[14]&~i[13];
assign outsel = i[17]&~i[15]&~i[14]&i[13];

//assign jcsel = i[15]&~i[14]&~i[13];
assign retok = i[17]&~i[16]&i[14]&flgchk;
assign retiok = i[17]&~i[16]&i[15]&i[14];
assign callok = i[17]&i[14]&i[13]&flgchk;
assign jumpok = i[17]&~i[15]&i[14]&~i[13]&flgchk;
//assign load = ~|i[15:12] | i[15]&i[14]&~i[13]&~i[12]&~i[3]&~i[2]&~i[1]&~i[0];
assign load = ~i[17]&~i[15]&~i[14]&~i[13];
assign flgchk = ((i[11] == 1'b0)?(zflag^i[10]):(cflag^i[10]))|(~i[12]);

// register bank
regbank2 u1 (.clk(clk),.we(rbwe),.aX(i[12:8]),.aY(i[7:3]),.sX(sX),.sXo(sXo),.sYo(sYo));

// arithmetic, logical, shifter
alus2 u2 (.clk(clk),.sX(sXo),.sY(sYo),.sXo(sXo1),.cin(cflag),.cout(cin),.zout(zin),.op(i[17:13]),.kk(i[7:0]));

// flags
initial cflag = 0;
always @(posedge clk) begin
if (flgwe|retiok) cflag <= cfgin;
	if (intok) intcf <= cflag;
end
assign cfgin = (retiok)?intcf:cin;

initial zflag = 0;
always @(posedge clk) begin
	if (flgwe|retiok) zflag <= zfgin;
	if (intok) intzf <= zflag;
end
assign zfgin = (retiok)?intzf:zin;

// input - output logic
assign port_id = (i[16] == 1'b1)?sYo:i[7:0];
assign outport = sXo;
assign sX = (read_strobe == 1'b1)?inport:sXo1;

// program control
initial sptr = 4'b0000;
initial pc = 10'h000;
stack2 u3 (.clk(clk),.we(clkdiv),.a(sptr),.di(pc),._do(stackout));
always @(posedge clk) begin
	if (~clkdiv) begin 
		stackoutr <= stackout;
		stackout1r <= stackout + 1'b1;
		pc1r <= pc + 1'b1;
	end
end
always @(posedge clk) begin
	if (~clkdiv) sptr <= sptr + 2'b01;	
	else begin
		if (callok|intok) sptr <= sptr;
		else if (retok) sptr <= sptr - 2'b10;
		else sptr <= sptr - 2'b01;
	end
end
always @(posedge clk) begin
	if (clkdiv) begin
		if (intok) pc <= 10'h3ff;
		else if (retiok) pc <= stackoutr;
		else if (retok) pc <= stackout1r;
		else if (callok|jumpok) pc <= i[9:0];
		else	pc <= pc1r;
	end
end
assign addr = pc;

endmodule


// 16 level stack for kcpsm processor
module stack2 (clk,we,a, di, _do);
input clk;
input we;
input [3:0] a;
input [9:0] di;
output [9:0] _do;
	
wire [3:0] a;
wire [9:0] di,_do;
wire clk,we;	
reg [9:0] ram [15:0];
	
always @(posedge clk) begin
	if (we) ram[a] <= di;
end
assign _do = ram[a];

endmodule


// regbank; 16 x 8bit register bank for kcpsm processor.
module regbank2(clk,we,aX,aY,sX,sXo,sYo);
input clk,we;
input [4:0] aX,aY;
input [7:0] sX;
output [7:0] sXo,sYo;

reg [7:0] ram [31:0];
initial begin
ram[31] = 0;
ram[30] = 0;
ram[29] = 0;
ram[28] = 0;
ram[27] = 0;
ram[26] = 0;
ram[25] = 0;
ram[24] = 0;
ram[23] = 0;
ram[22] = 0;
ram[21] = 0;
ram[20] = 0;
ram[19] = 0;
ram[18] = 0;
ram[17] = 0;
ram[16] = 0;
ram[15] = 0;
ram[14] = 0;
ram[13] = 0;
ram[12] = 0;
ram[11] = 0;
ram[10] = 0;
ram[9] = 0;
ram[8] = 0;
ram[7] = 0;
ram[6] = 0;
ram[5] = 0;
ram[4] = 0;
ram[3] = 0;
ram[2] = 0;
ram[1] = 0;
ram[0] = 0;
end 
// note, this doesn't match reality
wire [7:0] sXo,sYo;
wire [4:0] aX,aY;
wire clk,we;
wire [7:0] sX;

always @(posedge clk) begin
	if (we)
		ram[aX] <= sX;
end
assign sXo = ram[aX];
assign sYo = ram[aY];
endmodule


// alus; arithmetic, logical, shifter unit for KCPSM processor.
module alus2(clk,sX,sY,sXo,cin,cout,zout,op,kk);
input [7:0] sX,sY;
output [7:0] sXo;
input [7:0] kk;
input [4:0] op;
input cin,clk;
output cout,zout;

wire [7:0] sX,sY,sXoa,sXor,sXos;
wire [7:0] yk;
wire [7:0] kk;
wire [4:0] op;
//wire [2:0] sel;
wire clk,cin,coutr,couta,couts;
wire zout;
//wire as;

reg [7:0] sXo;
reg cout;

assign yk[7:0] = (op[3] == 1)?sY[7:0]:kk[7:0];
//assign sel[2:0] = (op[3] == 1)?kk[2:0]:op[2:0];

alu2 u1 (sX,yk,sXoa,cin,couta,op[2:0]);
shifter2 u2 (sX,sXos,cin,couts,kk[3:0]);

//assign as = op[3]&op[0];
assign sXor = (op[4])?sXos:sXoa;
assign coutr = (op[4])?couts:couta;
always @(posedge clk) begin
	sXo <= sXor;
	cout <= coutr;
end
assign zout = ~|sXo;
endmodule


module alu2(din1,din2,dout,cin,cout,select);
input [7:0] din1,din2;
output [7:0] dout;
input [2:0] select;
input cin;
output cout;

wire [7:0] din1,din2,douta,doutl,dout;
wire [2:0] select;
wire cin,coutl,couta,cout;

logical2 u1 (din1,din2,doutl,coutl,select[1:0]);
arithmetic2 u2 (din1,din2,douta,cin,couta,select[1:0]);

assign dout = (select[2] == 1)?douta:doutl;
assign cout = (select[2] == 1)?couta:coutl;
endmodule


module shifter2(din,dout,cin,cout,select);
input [7:0] din;
output [7:0] dout;
input [3:0] select;
input cin;
output cout;

wire [7:0] din,dout;
wire [3:0] select;
wire cin,cout;
wire irl;

assign dout[7:0] = (select[3] == 1)?{irl,din[7:1]}:{din[6:0],irl};
assign cout = (select[3] == 1)?din[0]:din[7];
assign irl = (select[2:1] == 2'b00)?cin:
             (select[2:1] == 2'b01)?din[7]:
             (select[2:1] == 2'b10)?din[0]:select[0];
endmodule


module logical2(din1,din2,dout,cout,select);
input [7:0] din1,din2;
output [7:0] dout;
input [1:0] select;
output cout;

wire [7:0] din1,din2;
reg [7:0] dout;
wire [1:0] select;

always @(select[1:0] or din1 or din2) begin
	case (select[1:0])
	2'b00: dout = din2;
	2'b01: dout = din1&din2;
	2'b10: dout = din1|din2;
	2'b11: dout = din1^din2;
	endcase
end
	 
assign cout = 1'b0;
endmodule


module arithmetic2(din1,din2,dout,cin,cout,select);
input [7:0] din1,din2;
output [7:0] dout;
input [1:0] select;
input cin;
output cout;

wire [7:0] din1,din2,dtmp,dout;
wire [8:0] tmp;
wire [1:0] select;
wire cin,cintmp,cout;

assign dtmp = din2^{8{select[1]}};
assign cintmp = (select[0] == 1'b0)?select[1]:(cin^select[1]);
assign tmp = din1 + dtmp + cintmp;
assign dout = tmp[7:0];
assign cout = tmp[8]^select[1];
endmodule	
