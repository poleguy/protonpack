`timescale 1ns / 1ps
// upper addresses are used for rs232 buffering... 0x80-0xff may not be used outside this module
	module rs_core #(
	
		parameter						prog_path = "E:/HDL/memory_init/AVNETRS.HEX",
		parameter						prog_depth = 10,
		parameter						clk_freq = 50000000,
		parameter						baud_rate = 115200
	)
	(
		output							serial_out,
		input							serial_in,
		input							clk,
		input							RESET,
		input		[7:0]				databusin,
		output		[7:0]				databusout,
		output		[7:0]				addrbus,
		output	reg	[15:0]				addr4to16,
		output							wr,
		output							re,
		input							extint,
		input		[prog_depth-7-1:0]	dms
	);





// I/O wire declarations
// 	wire serial_in,serial_out;
// 	wire clk,RESET;
// 	wire extint;

// wire/reg declarations for mpu2
//	wire wr,re;
	wire [7:0] inport,outport;
//	wire [7:0] addrbus;
//	wire [7:0] databusin,databusout;
	reg [7:0] databusrs, databusrsp;
	wire [9:0] progbus;
	wire [17:0] instrbus;

// wire declarations for UARTs
//	reg en_16_x_baud;
//	reg [9:0] baud_count;
	wire [7:0] data_out;
	reg [7:0] fifo_out;
	wire [7:0] fifo_in;
	wire rx_rdy,tx_done;
	reg snd_tx;

// wire declarations for int
	wire intr,interrupt_en,interrupt_rst;
	reg [7:0] interrupt;

//address decoding wire defs
//	reg [15:0] addr4to16;
	reg [15:0] addr00to0F;
	reg sel00to07;
//	reg sel10to17;
	reg sel10to7F;
	wire [7:0] rsI0,rsI1,rsI2,rsI3,rsI4,rsI5,rsI6,rsI7;

// Indirect addressing wire defs
	wire offreg_en,offreg_rst,indirect_en;
	wire [9:0] progbus_indr;
	reg [7:0] offreg;

// esm program memory
	(* rom_style = "block" *) reg [17:0] progrom [0:(2**prog_depth)-1];
	//reg [17:0] progrom [0:(2**prog_depth)-1];
	wire [17:0] dataram;
	reg [prog_depth-1:0] data_addr;
	reg [prog_depth-1:0] instr_addr;


// --------------------------------------------------------------------------------------


// program memory
	 initial begin
//	 	$readmemh("C:/Workfile/Xilinx/mpu/picoblaze_V2/CLPC.HEX", clpc_prog);
//		$readmemh("../memory_init/AVNETRS.HEX", progrom, 0, 1023);
//		$readmemh("E:/HDL/memory_init/AVNETRS.HEX", progrom, 0, 1023);
		$readmemh(prog_path, progrom, 0, (2**prog_depth)-1);
	 end
		
	assign instrbus = progrom[instr_addr];
	assign dataram = progrom[data_addr];
	
	always @(posedge clk) begin
		if (addrbus[7] == 1'b1 && wr == 1'b1) begin
			progrom[{dms,addrbus[6:0]}] <= {10'd0,outport};
		end
		data_addr <= {dms,addrbus[6:0]}; // upper addresses used for rs232 ram buffer
		instr_addr <= progbus_indr[prog_depth-1:0];

// 		instrbus <= progrom[progbus_indr[9:0]];
// 		dataram <= progrom[{3'b110,addrbus[6:0]}];

	end



//	wire [23:0] tmpvar1;
//	wire [15:0] tmpvar2;
//	wire [1:0] tmpvar3;
//   RAMB16 #(
//      .DOA_REG(0),  // Optional output registers on A port (0 or 1)
//      .DOB_REG(0),  // Optional output registers on B port (0 or 1)
//      .INIT_A(9'h00),  // Initial values on A output port
//      .INIT_B(18'h000),  // Initial values on B output port
//      .INVERT_CLK_DOA_REG("FALSE"),  // Invert clock on A port output registers ("TRUE" or "FALSE")
//      .INVERT_CLK_DOB_REG("FALSE"),  // Invert clock on A port output registers ("TRUE" or "FALSE")
//      .RAM_EXTENSION_A("NONE"),  // "UPPER", "LOWER" or "NONE" when cascaded
//      .RAM_EXTENSION_B("NONE"),  // "UPPER", "LOWER" or "NONE" when cascaded
//      .READ_WIDTH_A(9),  // Valid values are 1, 2, 4, 9, 18, or 36
//      .READ_WIDTH_B(18),  // Valid values are 1, 2, 4, 9, 18, or 36
//      .SIM_COLLISION_CHECK("ALL"),  // Collision check enable "ALL", "WARNING_ONLY", 
//                                    //   "GENERATE_X_ONLY" or "NONE
//      .SRVAL_A(9'h00), // Set/Reset value for A port output
//      .SRVAL_B(18'h000),  // Set/Reset value for B port output
//      .WRITE_MODE_A("WRITE_FIRST"),  // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE
//      .WRITE_MODE_B("WRITE_FIRST"),  // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE
//      .WRITE_WIDTH_A(9),  // Valid values are 1, 2, 4, 9, 18, or 36
//      .WRITE_WIDTH_B(18)  // Valid values are 1, 2, 4, 9, 18, or 36
//
//   ) progrom (
//      .CASCADEOUTA(),  // 1-bit cascade output
//      .CASCADEOUTB(),  // 1-bit cascade output
//      .DOA({tmpvar1,dataram}),      // 32-bit A port data output
//      .DOB({tmpvar2,instrbus[15:0]}),      // 32-bit B port data output
//      .DOPA(),    // 4-bit A port parity data output
//      .DOPB({tmpvar3,instrbus[17:16]}),    // 4-bit B port parity data output
//      .ADDRA({1'b0,4'b1110,addrbus[6:0],3'd0}),  // 15-bit A port address input
//      .ADDRB({1'b0,progbus_indr,4'd0}),  // 15-bit B port address input
//      .CASCADEINA(1'b0), // 1-bit cascade A input
//      .CASCADEINB(1'b0), // 1-bit cascade B input
//      .CLKA(clk),     // 1-bit A port clock input
//      .CLKB(clk),     // 1-bit B port clock input
//      .DIA({24'd0,outport}),       // 32-bit A port data input
//      .DIB({32'd0}),       // 32-bit B port data input
//      .DIPA(4'd0),     // 4-bit A port parity data input
//      .DIPB(4'd0),     // 4-bit B port parity data input
//      .ENA(1'b1),       // 1-bit A port enable input
//      .ENB(1'b1),       // 1-bit B port enable input
//      .REGCEA(1'b1), // 1-bit A port register enable input
//      .REGCEB(1'b1), // 1-bit B port register enable input
//      .SSRA(1'b0),     // 1-bit A port set/reset input
//      .SSRB(1'b0),     // 1-bit B port set/reset input
//      .WEA({4{addrbus[7] & wr}}),       // 4-bit A port write enable input
//      .WEB({4{1'b0}})        // 4-bit B port write enable input
//   );

/*
//rts Instantiate Altera Progrom
wire dopa;
alt_RAMB16_progrom	alt_RAMB16_progrom_inst (
	.address_a ( {4'b1110,addrbus[6:0]} ),
	.address_b ( progbus_indr ),
	.clock ( clk ),
	.data_a ( {1'b0, outport} ),
	.data_b ( ),
	.wren_a ( addrbus[7] & wr ),
	.wren_b ( 1'b0 ),
	.q_a ( {dopa, dataram} ),
	.q_b ( instrbus[17:0]  )
	);
// Memory for MPU and data
*/
/*rts remove X RAM
RAMB16_S9_S18 progrom (.DOA(dataram),
								.DOB(instrbus[15:0]),
								.DOPA(),
								.DOPB(instrbus[17:16]),
								.ADDRA({4'b1110,addrbus[6:0]}),
								.ADDRB(progbus_indr),
								.CLKA(clk),
								.CLKB(clk),
								.DIA(outport),
								.DIB(),
								.DIPA(1'b0),
								.DIPB(),
								.ENA(1'b1),
								.ENB(1'b1),
								.SSRA(1'b0),
								.SSRB(1'b0),
								.WEA(addrbus[7] & wr),
								.WEB(1'b0));

//Program ROM and descriptor table

//defparam progrom.INIT_00 = 256'h0000000000000000000000000000000000000000000000000000000000004020;
//defparam progrom.INIT_01 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_02 = 256'h2A170A802A120A312A110A015425CB400B3086012A3006100A00614161462603;
//defparam progrom.INIT_03 = 256'h2A200A0354982A200A0354982A800A034037C0012A310A632A100A012A170A00;
//defparam progrom.INIT_04 = 256'h54512A010A03548C2A020A0354982A040A0354912A080A0354982A100A035498;
//defparam progrom.INIT_05 = 256'h2820081789008900291809035C99C90127408848081350652802080007004098;
//defparam progrom.INIT_06 = 256'h280608000100749B81002838878007085474C70D083840996141614620FD5099;
//defparam progrom.INIT_07 = 256'h5C81C720074040992800614EC10150998100547DC70807404099614161465499;
//defparam progrom.INIT_08 = 256'h617850992704070040992800614E810128388780070840995885C77F07404099;
//defparam progrom.INIT_09 = 256'h820154C0CC770C100280C001260340994099617809034004271067FF07104099;
//defparam progrom.INIT_0A = 256'h8201062850C084006152051082010410820154C0CC200C10820154C0CC720C10;
//defparam progrom.INIT_0B = 256'h4000253054C0CC0D0C10820150C084006152051082010410820154C0CC200C10;
//defparam progrom.INIT_0C = 256'h051082010410820154FBCC200C10820154FBCC640C10820154FBCC720C100280;
//defparam progrom.INIT_0D = 256'h0320614B03108201614B0310C2026134614654FBCC0D0C10820150FB84006152;
//defparam progrom.INIT_0E = 256'h832758F0CC0A0C18830E830E830E830E23F004180328614B0320614B033D614B;
//defparam progrom.INIT_0F = 256'h8201550ACC770C1002804000614B8330832758F8CC0A0C18230F0320614B8330;
//defparam progrom.INIT_10 = 256'h0C108201551ACC720C100280400009034002550ACC0D0C108201550ACC660C10;
//defparam progrom.INIT_11 = 256'h036E614B03694000611D61464000617809034004551ACC0D0C108201551ACC66;
//defparam progrom.INIT_12 = 256'h036D614B0363614B0320614B0364614B0369614B036C614B0361614B0376614B;
//defparam progrom.INIT_13 = 256'h614B0320614B033A614B0372614B0364614B0364614B03614000614B0364614B;
//defparam progrom.INIT_14 = 256'h2F010F0740002300614E4000614B030A614B030D4000614B033E614B033E4000;
//defparam progrom.INIT_15 = 256'h8D0A5976CD610D205D76CD670D2041605976CD300D205D59CD3A0D20414E5000;
//defparam progrom.INIT_16 = 256'h8D068D068E0A5976CE610E285D76CE670E28416E5976CE300E285D67CE3A0E28;
//defparam progrom.INIT_17 = 256'h614B03688D480D130D18557CCD030D484000040040000401856805708D068D06;
//defparam progrom.INIT_18 = 256'h00000000000000000000000000000000400020FB50002D100D1709035C00C901;
//defparam progrom.INIT_19 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_1A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_1B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_1C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_1D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_1E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_1F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_20 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_21 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_22 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_23 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_24 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_25 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_26 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_27 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_28 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_29 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_2A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_2B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_2C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_2D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_2E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_2F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_30 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_31 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_32 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_33 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_34 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_35 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_36 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_37 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_38 = 256'h6900690048030E0061006C006F0072006F0074006F004D031204090304190703;
//defparam progrom.INIT_39 = 256'h0001010020020901000201000001010990080000000110011200610064006C00;
//defparam progrom.INIT_3A = 256'h00000000000000000040020105070000400281050700FFFFFF020000040932C0;
//defparam progrom.INIT_3B = 256'h0000000000000000000000000000000100000000000000000000000000000000;
//defparam progrom.INIT_3C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_3D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_3E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INIT_3F = 256'h4038000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INITP_00 = 256'hC7B331FF1331C7F3208CD31BCB2CB2CB2CB2F888888C4C3E0000000000000003;
//defparam progrom.INITP_01 = 256'h332C311C31AA1F333CF3F333CCCCCCCCBCCCF3331CF33333332BF08BF1ECC7C7;
//defparam progrom.INITP_02 = 256'hF4B1885AA31C7C7131C7C71E2AECCB32CCCCCCB33333333332FB0CCCCCC83333;
//defparam progrom.INITP_03 = 256'h0000000000000000000000000000000000000000000000000000000000008888;
//defparam progrom.INITP_04 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INITP_05 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INITP_06 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
//defparam progrom.INITP_07 = 256'hC000000000000000000000000000000000000000000000000000000000000000;

defparam progrom.INIT_00 = 256'h0000000000000000000000000000000000000000000000000000000000004020;
defparam progrom.INIT_01 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_02 = 256'h2A100A0354852A200A0354852A200A0354852A800A034024C001612E61332603;
defparam progrom.INIT_03 = 256'h080007004085543E2A010A0354792A020A0354852A040A03547E2A080A035485;
defparam progrom.INIT_04 = 256'h613320FD50862820081789008900291809035C86C90127408848081350522802;
defparam progrom.INIT_05 = 256'h612E61335486280608000100748881002838878007085461C70D08384086612E;
defparam progrom.INIT_06 = 256'hC77F074040865C6EC720074040862800613BC10150868100546AC70807404086;
defparam progrom.INIT_07 = 256'h67FF07104086616550862704070040862800613B810128388780070840865872;
defparam progrom.INIT_08 = 256'h54ADCC720C10820154ADCC770C100280C0012603408640866165090340042710;
defparam progrom.INIT_09 = 256'h54ADCC200C108201062850AD8400613F051082010410820154ADCC200C108201;
defparam progrom.INIT_0A = 256'hCC720C1002804000253054ADCC0D0C10820150AD8400613F0510820104108201;
defparam progrom.INIT_0B = 256'h50E88400613F051082010410820154E8CC200C10820154E8CC640C10820154E8;
defparam progrom.INIT_0C = 256'h6138033D6138032061380310820161380310C2026121613354E8CC0D0C108201;
defparam progrom.INIT_0D = 256'h032061388330832758DDCC0A0C18830E830E830E830E23F00418032861380320;
defparam progrom.INIT_0E = 256'h54F7CC660C10820154F7CC770C100280400061388330832758E5CC0A0C18230F;
defparam progrom.INIT_0F = 256'h82015507CC660C1082015507CC720C10028040000903400254F7CC0D0C108201;
defparam progrom.INIT_10 = 256'h613803766138036E613803694000610A613340006165090340045507CC0D0C10;
defparam progrom.INIT_11 = 256'h613803646138036D613803636138032061380364613803696138036C61380361;
defparam progrom.INIT_12 = 256'h6138033E4000613803206138033A613803726138036461380364613803614000;
defparam progrom.INIT_13 = 256'h0D20413B50002F010F0740002300613B40006138030A6138030D40006138033E;
defparam progrom.INIT_14 = 256'h5D54CE3A0E288D0A5963CD610D205D63CD670D20414D5963CD300D205D46CD3A;
defparam progrom.INIT_15 = 256'h05708D068D068D068D068E0A5963CE610E285D63CE670E28415B5963CE300E28;
defparam progrom.INIT_16 = 256'h09035C00C901613803688D480D130D185569CD030D4840000400400004018568;
defparam progrom.INIT_17 = 256'h00000000000000000000000000000000000000000000400020FB50002D100D17;
defparam progrom.INIT_18 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_19 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_1A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_1B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_1C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_1D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_1E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_1F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_20 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_21 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_22 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_23 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_24 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_25 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_26 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_27 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_28 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_29 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_2A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_2B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_2C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_2D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_2E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_2F = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_30 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_31 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_32 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_33 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_34 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_35 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_36 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_37 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_38 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_39 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_3A = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_3B = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_3C = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_3D = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_3E = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INIT_3F = 256'h4025000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INITP_00 = 256'h2FC7B31F1F1ECCC7FC4CC71FCC82334C6F2CB2CB2CB2CBFE0000000000000003;
defparam progrom.INITP_01 = 256'h333320CCCCCCB0C470C6A87CCCF3CFCCCF33333332F333CCCC73CCCCCCCCAFC2;
defparam progrom.INITP_02 = 256'h0000022223D2C6216A8C71F1C4C71F1C78ABB32CCB333332CCCCCCCCCCCBEC33;
defparam progrom.INITP_03 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INITP_04 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INITP_05 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INITP_06 = 256'h0000000000000000000000000000000000000000000000000000000000000000;
defparam progrom.INITP_07 = 256'hC000000000000000000000000000000000000000000000000000000000000000;
*/

// MPU
	mpu2 esm1 (
		.addr(progbus),
		.i(instrbus),
		.inport(inport),
		.outport(outport),
		.port_id(addrbus),
		.read_strobe(re),
		.write_strobe(wr),
		.interrupt(intr),
		.clk(clk)
	);


// rx and tx UARTs from Xilinx
//	kcuart_rx rx1 (
//		.serial_in(serial_in),
//		.data_out(data_out),
//		.data_strobe(rx_rdy),
//		.en_16_x_baud(en_16_x_baud),
//		.clk(clk)
//	);

	rs232_rx 
	#(
		.clk_freq(clk_freq),
		.baud_rate(baud_rate)
	) rx1 (
		.rx(serial_in),
		.clk(clk),
		.data(data_out),
		.enable(rx_rdy)
	);
	
//	kcuart_tx tx1 (
//		.data_in(data_in),
//		.send_character(snd_tx),
//		.en_16_x_baud(en_16_x_baud),
//		.serial_out(serial_out),
//		.Tx_complete(tx_done),
//		.clk(clk)
//	);

	rs232_tx
	#(
		.clk_freq(clk_freq),
		.baud_rate(baud_rate)
	) tx1 (
		.tx(serial_out),
		.clk(clk),
		.data(fifo_in),
		.enable(wr & addr00to0F[0]),
		.tx_done(tx_done)
	);


// 1 byte fifos between MPU and UART
	always @(posedge clk) begin
		if (rx_rdy) begin
			fifo_out <= data_out;
		end
		else begin
			fifo_out <= fifo_out;
		end
	end
	
/*
	register #(8) f1 (
		.d(data_out),
		.q(fifo_out),
		.en(rx_rdy),
		.rst(1'b0),
		.clk(clk)
	);
*/

//	register #(8) f2 (
//		.d(fifo_in),
//		.q(data_in),
//		.en(wr & addr00to0F[0]),
//		.rst(1'b0),
//		.clk(clk)
//	);

	always @(posedge clk) begin
		if (tx_done == 1'b1) begin
			snd_tx <= 1'b0;
		end
		else if (wr & addr00to0F[0]) begin
			snd_tx <= 1'b1;
		end
		else begin
			snd_tx <= snd_tx;
		end
	end
/*
	register #(1) r1 (
		.d(1'b1),
		.q(snd_tx),
		.en(wr & addr00to0F[0]),
		.rst(tx_done),
		.clk(clk)
	);
*/
	assign fifo_in = outport;


// rx_rdy_latch for 2 cycle minimum interrupt
	reg rx_rdy_latch;
	always @(posedge clk)
	  begin
	    if ( rx_rdy )
	      rx_rdy_latch  <= 1'b1;
	    else if ( ( addrbus == 8'h00 ) && ( re ) )
	      rx_rdy_latch  <= 1'b0;
	    else
	      rx_rdy_latch  <= rx_rdy_latch;
	  end

// below baud gen not used with gleason UARTS
/*
// baud clock generator for above UART
	initial baud_count = 10'h000;
	always @(posedge clk) begin
		if (baud_count == 10'd26) begin			// 115200
//		if (baud_count == 325) begin		// 9600
			baud_count <= 1'b0;
			en_16_x_baud <= 1'b1;
		end
		else begin
			baud_count <= baud_count + 1;
			en_16_x_baud <= 1'b0;
		end
	end
*/


// registers for MPU output
	initial offreg = 8'h00;
	assign indirect_en = ~(|progbus[7:5]);
	assign offreg_en = (wr & addr00to0F[6]);
	assign offreg_rst = RESET|indirect_en;
	always @(posedge clk) begin
		if (offreg_rst == 1) offreg <= 8'h00;
		else if (offreg_en == 1) offreg <= outport;
		else offreg <= offreg;
	end
	assign progbus_indr = (indirect_en == 1)?(progbus + offreg):progbus;


// MPU input registers
	initial interrupt = 8'h00;
	assign intr = |interrupt[5:0];
//	assign interrupt_en = 1'b0|1'b0|1'b0|1'b0|extint|1'b0|tx_done|rx_rdy;
	assign interrupt_en = 1'b0|1'b0|1'b0|1'b0|extint|1'b0|tx_done|rx_rdy_latch;
	assign interrupt_rst = (wr & addr00to0F[3]);
	always @(posedge clk) begin
		if (interrupt_rst == 1) interrupt <= 8'h00;
//		else if (interrupt_en == 1) interrupt <= {1'b0,1'b0,1'b0,1'b0,extint,1'b0,tx_done,rx_rdy};
		else if (interrupt_en == 1) interrupt <= {1'b0,1'b0,1'b0,1'b0,extint,1'b0,tx_done,rx_rdy_latch};
		else interrupt <= interrupt;
	end

	assign databusout = outport;


//multiplexor for usb databus, descriptor table, ext databus
	assign inport = (sel00to07)?databusrsp:
					(addrbus[7])?dataram[7:0]: // this selects a ram for buffering rs232
					(sel10to7F)?databusin:8'hff;


//multiplexer for USB signals
	assign rsI0 = fifo_out;
	assign rsI1 = 8'hff;
	assign rsI2 = 8'hff;
	assign rsI3 = interrupt;
	assign rsI4 = 8'hff;
	assign rsI5 = 8'hff;
	assign rsI6 = 8'hff;
	assign rsI7 = {7'h00,snd_tx};
	always @(addrbus[2:0] or rsI0 or rsI1 or rsI2 or rsI3 or rsI4 or rsI5 or rsI6 or rsI7) begin
		case (addrbus[2:0])
			3'b000 : databusrs = rsI0;
			3'b001 : databusrs = rsI1;
			3'b010 : databusrs = rsI2;
			3'b011 : databusrs = rsI3;
			3'b100 : databusrs = rsI4;
			3'b101 : databusrs = rsI5;
			3'b110 : databusrs = rsI6;
			3'b111 : databusrs = rsI7;
		endcase
	end


//pipeline for databususb
	always @(posedge clk) begin
		databusrsp <= databusrs;
	end


//logic for selecting USB databus or external databus
	always @(posedge clk) begin
		sel00to07 <= (addrbus[7:3] == 5'b00000)?1'b1:1'b0;
//		sel10to17 <= (addrbus[7:3] == 5'b00010)?1'b1:1'b0;
		sel10to7F <= (addrbus >= 8'h10 && addrbus <= 8'h7F)?1'b1:1'b0;
	end


//mpu2 address decoding
//RS323 UART in/out											00
//UNUSED													01
//UNUSED													02
//int reset/interrupt										03
//UNUSED													04			
//UNUSED													05							
//offset for indirect program addressing					06
//UNUSED													07
//UNUSED													08
//UNUSED													09
//UNUSED													0A
//UNUSED													0B
//UNUSED													0C
//UNUSED													0D
//UNUSED													0E
//UNUSED													0F


//4 to 16 address decoder
	always @(addrbus[3:0] or addr4to16) begin
		case (addrbus[3:0])
			4'h0 : addr4to16 = 16'h0001;
			4'h1 : addr4to16 = 16'h0002;
			4'h2 : addr4to16 = 16'h0004;
			4'h3 : addr4to16 = 16'h0008;
			4'h4 : addr4to16 = 16'h0010;
			4'h5 : addr4to16 = 16'h0020;
			4'h6 : addr4to16 = 16'h0040;
			4'h7 : addr4to16 = 16'h0080;
			4'h8 : addr4to16 = 16'h0100;
			4'h9 : addr4to16 = 16'h0200;
			4'hA : addr4to16 = 16'h0400;
			4'hB : addr4to16 = 16'h0800;
			4'hC : addr4to16 = 16'h1000;
			4'hD : addr4to16 = 16'h2000;
			4'hE : addr4to16 = 16'h4000;
			default : addr4to16 = 16'h8000;
		endcase
	end


// pipeline addrbus decoded outputs for speed
	always @(posedge clk) begin
		addr00to0F[15:0] = addr4to16[15:0] & {16{(~|addrbus[7:4])}};
	end


	endmodule


	module rs232_rx
	#(
		parameter clk_freq = 50000000,
		parameter baud_rate = 115200
	)
	(
		input rx,
		input clk,
		output reg [7:0] data,
		output reg enable
	);	 

	reg [15:0] counter;
	reg [3:0] bits;
	reg [1:0] state;
	reg rx1;
	reg rx2;
	reg rx3;

	initial begin
		counter = 0;
		bits = 0;
		state = 0;
		rx1 = 0;
		rx2 = 0;
		rx3 = 0;
	end

	always @ (posedge clk) begin
		rx1 <= rx;
		rx2 <= rx1;
		rx3 <= rx2;
	
		case (state)
			2'b00: begin
//				counter <= 16'd213;   //  Change this count value to adjust for buad rate / system clock "1/2 a bit time"
//				counter <= 16'd217;   //  Change this count value to adjust for buad rate / system clock "1/2 a bit time"
//				counter <= 16'd52;    //  12 MHz clock, 115.2 Kbaud
				counter <= clk_freq/(2*baud_rate);
				data <= data;
				bits <= 0;
				enable <= 0;
				if((rx2 == 0)&&(rx3 == 1))state <= 2'b1;
				else state <= 2'b0;
			end
			
			2'b01: begin
				if ( 0 == counter)begin
//					counter <= 16'd451;	//  Change this count value to adjust for buad rate / system clock "a bit time"
//					counter <= 16'd434;	//  Change this count value to adjust for buad rate / system clock "a bit time"
//					counter <= 16'd104;	//  12 MHz clock, 115.2 Kbaud
					counter <= clk_freq/baud_rate;
					data <= {rx3,data[7:1]};
					bits <= bits + 4'd1;
				end else counter <= counter - 16'd1;
				enable <= 0;
				if (bits == 4'h9)state <= 2'b10;
				else state <= 2'b01;
			end
			
			2'b10: begin
				counter <= 16'd0;
				enable <= 1;
				data <= data;
				bits <= bits;
				state <= 2'b0;
			end
			
			default:
				state <= 2'b0;
		
		endcase
	
	end


	endmodule


//  This is just an accessory module to hold the enable bit high for two clocks for inteface with a esm

	module hold_enable (
		input clk,
		input enable_in,
		output reg enable_out
	);
							
	reg hold=0;
	
	always@(posedge clk)
	begin
		if(enable_in)
			begin
				enable_out <= 1'b1;
				hold <= 1'b1;
				end
			else
				if(hold)
				begin
					enable_out <= 1'b1;
					hold <= 1'b0;
					end
				else
					enable_out <= 1'b0;
		end
	
	endmodule


	module rs232_tx
	#(
		parameter clk_freq = 50000000,
		parameter baud_rate = 115200
	)
	(
		output reg tx,
		input clk,
		input [7:0] data,
		input enable,
		output reg tx_done = 1'b0
	);	 

	reg [15:0] counter;
	reg [3:0] bits;
	reg [1:0] state;
	reg [9:0] data_int;
	reg [1:0] past_state = 2'd0;
	reg past_done = 1'b0;
	reg done = 1'b0;

	initial begin
		counter = 0;
		bits = 0;
		state = 0;
		data_int = 0;
	end

	always @ (posedge clk) begin
		
		case (state)
			2'b00: begin
				counter <= 16'd0;
				tx <= 1;
				data_int <= {1'b1,data[7:0],1'b0};
				bits <= 4'd11;
				if( 1'b1 == enable )state <= 2'b01;
				else state <= 2'b00;
			end
			
			2'b01: begin
				if ( 16'd0 == counter)begin
//					counter <= 16'd427;		//  Change this count value to adjust for buad rate / system clock "a bit time"
//					counter <= 16'd434;		//  50 MHz clock
//					counter <= 16'd104;		//	12 MHz clock, 115.2 Kbaud
					counter <= clk_freq/baud_rate;
					tx <= data_int[0];
					data_int <= {1'b1,data_int[9:1]};
					bits <= bits - 4'd1;
				end else begin
					counter <= counter - 16'd1;
					tx <= tx;
					data_int <= data_int;
					bits <= bits;
				end
				if (bits == 4'h0)state <= 2'b00;
				else state <= 2'b01;
			end
			
			default:
				state <= 2'b00;
		
		endcase
		
	end


	always @(posedge clk) begin
		past_state <= state;
		past_done <= done;
		tx_done <= past_done | done;
		if((state == 2'b00) && (past_state == 2'b01)) begin
			done <= 1'b1;
		end
		else begin
			done <= 1'b0;
		end
	end
	

endmodule