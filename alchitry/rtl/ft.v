do not use
`timescale 1ns/1ps
`default_nettype none //do not use implicit wire for port connections
module ft (
	clk,
	rst,
	ft_clk,
	ft_rxf,
	ft_txe,
	ft_data,
	ft_be,
	ft_rd,
	ft_wr,
	ft_oe,
	ui_din,
	ui_din_be,
	ui_din_valid,
	ui_din_full,
	ui_dout,
	ui_dout_be,
	ui_dout_empty,
	ui_dout_get
);
	parameter BUS_WIDTH = 5'h10;
	parameter TX_BUFFER = 7'h40;
	parameter RX_BUFFER = 7'h40;
	parameter PRIORITY = 16'h5258;
	parameter PREEMPT = 1'h0;
	input wire clk;
	input wire rst;
	input wire ft_clk;
	input wire ft_rxf;
	input wire ft_txe;
	inout wire [BUS_WIDTH - 1:0] ft_data;
	inout wire [(BUS_WIDTH / 4'h8) - 1:0] ft_be;
	output reg ft_rd;
	output reg ft_wr;
	output reg ft_oe;
	input wire [BUS_WIDTH - 1:0] ui_din;
	input wire [(BUS_WIDTH / 4'h8) - 1:0] ui_din_be;
	input wire ui_din_valid;
	output reg ui_din_full;
	output reg [BUS_WIDTH - 1:0] ui_dout;
	output reg [(BUS_WIDTH / 4'h8) - 1:0] ui_dout_be;
	output reg ui_dout_empty;
	input wire ui_dout_get;
	reg [BUS_WIDTH - 1:0] IO_ft_data;
	assign ft_data = IO_ft_data;
	reg [(BUS_WIDTH / 4'h8) - 1:0] IO_ft_be;
	assign ft_be = IO_ft_be;
	reg L_0054483b_reading_bus;
	reg [1:0] L_0054483b_prefered_state;
	reg L_0054483b_can_write;
	reg L_0054483b_can_read;
	// localparam E_State_IDLE = 2'h0;
	// localparam E_State_BUS_SWITCH = 2'h1;
	// localparam E_State_READ = 2'h2;
	// localparam E_State_WRITE = 2'h3;
	reg [1:0] D_state_d;
	reg [1:0] D_state_q = 0;
	function automatic [5:0] sv2v_cast_A58F0;
		input reg [5:0] inp;
		sv2v_cast_A58F0 = inp;
	endfunction
	localparam _MP_WIDTH_28041744 = sv2v_cast_A58F0(BUS_WIDTH + ({1'b0,BUS_WIDTH} / 6'h8));
	localparam _MP_ENTRIES_28041744 = TX_BUFFER;
	localparam _MP_SYNC_STAGES_28041744 = 2'h3;
	reg [_MP_WIDTH_28041744 - 1:0] M_write_fifo_din;
	reg M_write_fifo_wput;
	wire M_write_fifo_full;
	wire [_MP_WIDTH_28041744 - 1:0] M_write_fifo_dout;
	reg M_write_fifo_rget;
	wire M_write_fifo_empty;
	async_fifo #(
		.WIDTH(_MP_WIDTH_28041744),
		.ENTRIES(_MP_ENTRIES_28041744),
		.SYNC_STAGES(_MP_SYNC_STAGES_28041744)
	) write_fifo(
		.rclk(ft_clk),
		.rrst(rst),
		.wclk(clk),
		.wrst(rst),
		.din(M_write_fifo_din),
		.wput(M_write_fifo_wput),
		.full(M_write_fifo_full),
		.dout(M_write_fifo_dout),
		.rget(M_write_fifo_rget),
		.empty(M_write_fifo_empty)
	);
	localparam _MP_WIDTH_462831266 = sv2v_cast_A58F0(BUS_WIDTH + ({1'b0,BUS_WIDTH} / 6'h8));
	localparam _MP_ENTRIES_462831266 = RX_BUFFER;
	localparam _MP_SYNC_STAGES_462831266 = 2'h3;
	reg [_MP_WIDTH_462831266 - 1:0] M_read_fifo_din;
	reg M_read_fifo_wput;
	wire M_read_fifo_full;
	wire [_MP_WIDTH_462831266 - 1:0] M_read_fifo_dout;
	reg M_read_fifo_rget;
	wire M_read_fifo_empty;
	async_fifo #(
		.WIDTH(_MP_WIDTH_462831266),
		.ENTRIES(_MP_ENTRIES_462831266),
		.SYNC_STAGES(_MP_SYNC_STAGES_462831266)
	) read_fifo(
		.rclk(clk),
		.rrst(rst),
		.wclk(ft_clk),
		.wrst(rst),
		.din(M_read_fifo_din),
		.wput(M_read_fifo_wput),
		.full(M_read_fifo_full),
		.dout(M_read_fifo_dout),
		.rget(M_read_fifo_rget),
		.empty(M_read_fifo_empty)
	);
	function automatic [5:0] sv2v_cast_5447A;
		input reg [5:0] inp;
		sv2v_cast_5447A = inp;
	endfunction
	always @(*) begin
		D_state_d = D_state_q;
		M_write_fifo_wput = ui_din_valid;
		M_write_fifo_din = {ui_din_be, ui_din};
		ui_din_full = M_write_fifo_full;
		ui_dout = M_read_fifo_dout[sv2v_cast_5447A(BUS_WIDTH - 1'h1):1'h0];
		ui_dout_be = M_read_fifo_dout[_MP_WIDTH_462831266 - 1-:BUS_WIDTH / 4'h8];
		ui_dout_empty = M_read_fifo_empty;
		M_read_fifo_rget = ui_dout_get;
		M_read_fifo_din = {ft_be, ft_data};
		M_read_fifo_wput = 1'h0;
		M_write_fifo_rget = 1'h0;
		ft_oe = 1'h1;
		ft_rd = 1'h1;
		ft_wr = 1'h1;
		L_0054483b_reading_bus = (D_state_q == 2'h1) || (D_state_q == 2'h2);
		IO_ft_data = (L_0054483b_reading_bus ? {BUS_WIDTH {1'bz}} : M_write_fifo_dout[sv2v_cast_5447A(BUS_WIDTH - 1'h1):1'h0]);
		IO_ft_be = (L_0054483b_reading_bus ? {BUS_WIDTH / 4'h8 {1'bz}} : M_write_fifo_dout[_MP_WIDTH_462831266 - 1-:BUS_WIDTH / 4'h8]);
		L_0054483b_prefered_state = 2'h0;
		L_0054483b_can_write = (ft_txe == 1'h0) && (M_write_fifo_empty == 1'h0);
		L_0054483b_can_read = (ft_rxf == 1'h0) && (M_read_fifo_full == 1'h0);
		if (L_0054483b_can_write && ((PRIORITY == 16'h5458) || !L_0054483b_can_read))
			L_0054483b_prefered_state = 2'h3;
		if (L_0054483b_can_read && ((PRIORITY == 16'h5258) || !L_0054483b_can_write))
			L_0054483b_prefered_state = 2'h1;
		case (D_state_q)
			2'h0: D_state_d = L_0054483b_prefered_state;
			2'h1: begin
				ft_oe = 1'h0;
				D_state_d = 2'h2;
			end
			2'h2: begin
				ft_oe = M_read_fifo_full;
				ft_rd = M_read_fifo_full;
				M_read_fifo_wput = !ft_rxf;
				if ((ft_rxf || M_read_fifo_full) || (PREEMPT && (L_0054483b_prefered_state == 2'h3)))
					D_state_d = L_0054483b_prefered_state;
			end
			2'h3: begin
				ft_wr = M_write_fifo_empty;
				M_write_fifo_rget = !ft_txe;
				if ((ft_txe || M_write_fifo_empty) || (PREEMPT && (L_0054483b_prefered_state == 2'h1)))
					D_state_d = L_0054483b_prefered_state;
			end
		endcase
	end
	always @(posedge ft_clk) D_state_q <= D_state_d;
endmodule

`resetall
