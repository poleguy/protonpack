module reset_conditioner (
	clk,
	in,
	out
);
	parameter STAGES = 3'h4;
	input wire clk;
	input wire in;
	output reg out;
	reg [STAGES - 1:0] D_stage_d;
	reg [STAGES - 1:0] D_stage_q = {STAGES {1'h1}};
	function automatic [3:0] sv2v_cast_E264A;
		input reg [3:0] inp;
		sv2v_cast_E264A = inp;
	endfunction
	function automatic [3:0] sv2v_cast_5891A;
		input reg [3:0] inp;
		sv2v_cast_5891A = inp;
	endfunction
	always @(*) begin
		D_stage_d = D_stage_q;
		D_stage_d = {D_stage_q[sv2v_cast_E264A(STAGES - 2'h2):1'h0], 1'h0};
		out = D_stage_q[sv2v_cast_5891A(STAGES - 1'h1)];
	end
	always @(posedge clk or posedge in)
		if (in == 1'b1)
			D_stage_q <= {STAGES {1'h1}};
		else
			D_stage_q <= D_stage_d;
endmodule
