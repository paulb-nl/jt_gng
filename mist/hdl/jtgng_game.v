`timescale 1ns/1ps

module jtgng_game(
	input			rst,
	input			clk_rom, //  81   MHz
	input			clk  	 //   6   MHz
);

	wire [8:0] V;
	wire [8:0] H;
	wire Hinit;
	wire LHBL;
	wire LVBL;

	wire [12:0] cpu_AB;
	wire char_cs;
	wire flip;
	wire [7:0] cpu_dout, char_dout;
	wire rd;
	wire char_mrdy;
	wire [13:0] char_addr;
	wire [7:0] char_data = 8'h00;
	wire [1:0] char_col;
	wire rom_ready;

reg rst_game;
reg rst_aux;

always @(posedge clk or posedge rst)
	if( rst || !rom_ready ) begin
		{rst_game,rst_aux} <= 2'b11;
	end
	else begin
		{rst_game,rst_aux} <= {1'b0, rst_game};
	end

jtgng_timer timers (.clk(clk), .rst(rst), .V(V), .H(H), .Hinit(Hinit), .LHBL(LHBL), .LVBL(LVBL));

	wire RnW;

jtgng_char chargen (
	.clk      ( clk      	),
	.AB       ( cpu_AB[10:0]),
	.V128     ( V[7:0]   	),
	.H128     ( H[7:0]   	),
	.char_cs  ( char_cs  	),
	.flip     ( flip     	),
	.din      ( cpu_dout 	),
	.dout     ( char_dout	),
	.rd       ( RnW      	),
	.MRDY_b   ( char_mrdy	),
	.char_addr( char_addr	),
	.char_data( char_data	),
	.char_col ( char_col 	)
);

	wire bus_ack, bus_req;
	wire [17:0] main_addr;
	wire [7:0] main_dout;
jtgng_main main (
	.clk      	( clk      	),
	.rst      	( rst_game 	),
	.ch_mrdy  	( char_mrdy	),
	.char_dout	( char_dout	),
	.LVBL     	( LVBL     	),
	.cpu_dout 	( cpu_dout 	),
	.char_cs  	( char_cs  	),
	.flip		( flip		),
	.bus_ack 	( bus_ack  	),
	.cpu_AB	 	( cpu_AB	),
	.RnW	 	( RnW		),
	.rom_addr	( main_addr ),
	.rom_dout	( main_dout )
);


	wire [14:0] snd_addr=0;
	wire [14:0] obj_addr=0;
	wire [15:0] scr_addr=0;
	wire [7:0] snd_dout;
	wire [15:0] obj_dout;
	wire [23:0] scr_dout;
jtgng_rom rom (
	.clk      (clk_rom  ),
	.rst      (rst      ),
	.char_addr(char_addr),
	.main_addr(main_addr),
	.snd_addr (snd_addr ),
	.obj_addr (obj_addr ),
	.scr_addr (scr_addr ),
	.char_dout(char_dout),
	.main_dout(main_dout),
	.snd_dout (snd_dout ),
	.obj_dout (obj_dout ),
	.scr_dout (scr_dout ),
	.ready	  (rom_ready)
);


endmodule // jtgng