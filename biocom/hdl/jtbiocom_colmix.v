/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-9-2019 */

`timescale 1ns/1ps

module jtbiocom_colmix(
    input            rst,
    input            clk,
    input            cen6 /* synthesis direct_enable = 1 */,

    // pixel input from generator modules
    input [5:0]      char_pxl,        // character color code
    input [7:0]      scr1_pxl,
    input [7:0]      scr2_pxl,
    input [7:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output  reg      LHBL_dly,
    output  reg      LVBL_dly,
    // Priority PROM
    input [7:0]      prog_addr,
    input            prom_prio_we,
    input [3:0]      prom_din,
    // Avatars
    // input [3:0]      avatar_idx,
    // input            pause,
    // CPU inteface
    input [10:1]     AB,
    input            col_cs,
    input [15:0]     DB,

    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter PALETTE_PRIOR = "../../../rom/biocom/63s141.18f";

reg [7:0] pixel_mux;

wire enable_char = gfx_en[0];
wire enable_scr  = gfx_en[1];
wire obj_blank   = &obj_pxl[3:0];
wire enable_obj  = gfx_en[3];

// SCRWIN means that the MSB of scr_pxl signals that the background
// tile should go on top of the sprites, changing the priority order.
// When SCRWIN=0 then the MSB of scr_pxl has no special meaning.
//reg  [2:0] obj_sel; // signals whether an object pixel is selected
wire [1:0] selbus;
reg  [7:0] seladdr;
reg  [1:0] muxsel;
reg        char_blank_n = |(~char_pxl[1:0]);

always @(*) begin
    seladdr[0]   = |(~scr2_pxl[3:0]);
    seladdr[6:1] = { scr1_pxl[7:6], scr1_pxl[3:0] };
    seladdr[7]   = |(~obj_pxl[3:0]);
    muxsel       = selbus | {2{char_blank_n}};
end

always @(posedge clk) if(cen6) begin
    case( muxsel )
        2'b11: pixel_mux = { 2'b0, char_pxl };
        2'b01: pixel_mux = obj_pxl;
        2'b10: pixel_mux = { 2'b0, scr1_pxl[5:0] };
        2'b11: pixel_mux = { 1'b0, scr2_pxl[6:0] };
    endcase
end

// Blanking delay
wire [1:0] pre_BL;

jtgng_sh #(.width(2),.stages(5)) u_blank_dly(
    .clk    ( clk      ),
    .clk_en ( cen6     ),
    .din    ( {LHBL, LVBL}     ),
    .drop   ( pre_BL   )
);

// Address mux
reg  [9:0] pal_addr;
reg        pal_we;
reg        coloff; // colour off
wire [3:0] pal_red, pal_green, pal_blue, pal_bright;

always @(*) begin
    if( pre_BL!=2'b11 ) begin
        pal_addr = AB;
        pal_we   = col_cs;
    end else begin
        pal_addr = pixel_mux;
        pal_we   = 1'b0;
    end
end

always @(posedge clk) if(cen6) begin
    coloff <= pre_BL!=2'b11;
    {LHBL_dly, LVBL_dly} <= pre_BL;
end


// Palette is in RAM

jtgng_ram #(.aw(10),.dw(16)) u_pal(
    .clk        ( clk         ),
    .cen        ( cen6        ), // clock enable only applies to write operation
    .data       ( DB          ),
    .addr       ( pal_addr    ),
    .we         ( pal_we      ),
    .q          ( {pal_red, pal_green, pal_blue, pal_bright } )
);


// `ifdef AVATARS
// `ifdef MISTER
// `define AVATAR_PAL
// `endif
// `endif
// 
// `ifdef AVATAR_PAL
// wire [11:0] avatar_pal;
// // Objects have their own palette during pause
// wire [ 7:0] avatar_addr = { avatar_idx, obj_pxl[0], obj_pxl[1], obj_pxl[2], obj_pxl[3] };
// 
// jtgng_ram #(.dw(12),.aw(8), .synfile("avatar_pal.hex"),.cen_rd(1))u_avatars(
//     .clk    ( clk           ),
//     .cen    ( pause         ),  // tiny power saving when not in pause
//     .data   ( 12'd0         ),
//     .addr   ( avatar_addr   ),
//     .we     ( 1'b0          ),
//     .q      ( avatar_pal    )
// );
// // Select the avatar palette output if we are on avatar mode
// wire [11:0] avatar_mux = (pause&&obj_sel[1]) ? avatar_pal : { pal_red, pal_green, pal_blue };
// `else 
// wire [11:0] avatar_mux = {pal_red, pal_green, pal_blue};
// `endif

// Clock must be faster than 6MHz so selbus is ready for the next
// 6MHz clock cycle:
jtgng_prom #(.aw(8),.dw(2),.simfile(PALETTE_PRIOR)) u_selbus(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prio_we  ),
    .q      ( selbus        )
);

function [3:0] dim;
    input [3:0]  col;
    input        dim_set;
    dim = dim_set ? {1'b0, col[3:1]} : col; // To do: fix accuracy
endfunction

always @(posedge clk) if (cen6)
    {red, green, blue } <= (!coloff && !pal_bright[3]) ? 
        { dim(pal_red,   pal_bright[2]),
          dim(pal_green, pal_bright[1]),
          dim(pal_blue,  pal_bright[0]) } : 12'd0;

endmodule // jtgng_colmix