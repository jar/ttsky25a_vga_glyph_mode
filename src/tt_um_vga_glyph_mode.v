/*
 * Copyright (c) 2024 James Ross
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_glyph_mode(
	input  wire [7:0] ui_in,    // Dedicated inputs
	output wire [7:0] uo_out,   // Dedicated outputs
	input  wire [7:0] uio_in,   // IOs: Input path
	output wire [7:0] uio_out,  // IOs: Output path
	output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
	input  wire       ena,      // always 1 when the design is powered, so you can ignore it
	input  wire       clk,      // clock
	input  wire       rst_n     // reset_n - low to reset
);

	// VGA signals
	wire hsync;
	wire vsync;
	wire [1:0] R;
	wire [1:0] G;
	wire [1:0] B;
	wire video_active;
	wire [9:0] pix_x;
	wire [9:0] pix_y;

	// TinyVGA PMOD
	assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

	// Unused outputs assigned to 0.
	assign uio_out = 0;
	assign uio_oe  = 0;

	wire [6:0] x_block = pix_x[9:3];
	wire [2:0] g_x = pix_x[2:0];
	wire [5:0] y_block = y_mem[pix_y[8:2]];
	wire [9:0] g_y9 = pix_y - {y_block, 3'b000} - {1'b0, y_block, 2'b00};
	wire [3:0] g_y = g_y9[3:0];
	wire hl;

	// Suppress unused signals warning
	wire _unused_ok = &{ena, ui_in, uio_in};

	reg [9:0] counter;

	hvsync_generator hvsync_gen(
		.clk(clk),
		.reset(~rst_n),
		.hsync(hsync),
		.vsync(vsync),
		.display_on(video_active),
		.hpos(pix_x),
		.vpos(pix_y)
	);

	// glyphs
	glyphs_rom glyphs (
			.c(glyph_index),
			.y(g_y),
			.x(g_x),
			.pixel(hl)
	);

	wire [4:0] glyph_index = {x_block[2] ^ y_block[0]^counter[0], x_block[0] ^ y_block[1], x_block[1] ^ y_block[2], x_block[4] ^ y_block[3], x_block[3] ^ y_block[4]};
	wire [5:0] color = RGB[5];

	assign R = video_active ? {color[5] & hl, color[4] & hl} : 2'b00;
	assign G = video_active ? {color[3] & hl, color[2] & hl} : 2'b00;
	assign B = video_active ? {color[1] & hl, color[0] & hl} : 2'b00;
	
	always @(posedge vsync) begin
		if (~rst_n) begin
			counter <= 0;
		end else begin
			counter <= counter + 1;
		end
	end

	reg [5:0] RGB[0:7];
	initial begin
		RGB[0] = 6'b000000;
		RGB[1] = 6'b000100;
		RGB[2] = 6'b001000;
		RGB[3] = 6'b001100;
		RGB[4] = 6'b011100;
		RGB[5] = 6'b101101;
		RGB[6] = 6'b111110;
		RGB[7] = 6'b111111;
	end

	// Division-by-3 lookup
	reg [5:0] y_mem[0:119];
	initial begin
		y_mem[  0] = 6'd0;
		y_mem[  1] = 6'd0;
		y_mem[  2] = 6'd0;
		y_mem[  3] = 6'd1;
		y_mem[  4] = 6'd1;
		y_mem[  5] = 6'd1;
		y_mem[  6] = 6'd2;
		y_mem[  7] = 6'd2;
		y_mem[  8] = 6'd2;
		y_mem[  9] = 6'd3;
		y_mem[ 10] = 6'd3;
		y_mem[ 11] = 6'd3;
		y_mem[ 12] = 6'd4;
		y_mem[ 13] = 6'd4;
		y_mem[ 14] = 6'd4;
		y_mem[ 15] = 6'd5;
		y_mem[ 16] = 6'd5;
		y_mem[ 17] = 6'd5;
		y_mem[ 18] = 6'd6;
		y_mem[ 19] = 6'd6;
		y_mem[ 20] = 6'd6;
		y_mem[ 21] = 6'd7;
		y_mem[ 22] = 6'd7;
		y_mem[ 23] = 6'd7;
		y_mem[ 24] = 6'd8;
		y_mem[ 25] = 6'd8;
		y_mem[ 26] = 6'd8;
		y_mem[ 27] = 6'd9;
		y_mem[ 28] = 6'd9;
		y_mem[ 29] = 6'd9;
		y_mem[ 30] = 6'd10;
		y_mem[ 31] = 6'd10;
		y_mem[ 32] = 6'd10;
		y_mem[ 33] = 6'd11;
		y_mem[ 34] = 6'd11;
		y_mem[ 35] = 6'd11;
		y_mem[ 36] = 6'd12;
		y_mem[ 37] = 6'd12;
		y_mem[ 38] = 6'd12;
		y_mem[ 39] = 6'd13;
		y_mem[ 40] = 6'd13;
		y_mem[ 41] = 6'd13;
		y_mem[ 42] = 6'd14;
		y_mem[ 43] = 6'd14;
		y_mem[ 44] = 6'd14;
		y_mem[ 45] = 6'd15;
		y_mem[ 46] = 6'd15;
		y_mem[ 47] = 6'd15;
		y_mem[ 48] = 6'd16;
		y_mem[ 49] = 6'd16;
		y_mem[ 50] = 6'd16;
		y_mem[ 51] = 6'd17;
		y_mem[ 52] = 6'd17;
		y_mem[ 53] = 6'd17;
		y_mem[ 54] = 6'd18;
		y_mem[ 55] = 6'd18;
		y_mem[ 56] = 6'd18;
		y_mem[ 57] = 6'd19;
		y_mem[ 58] = 6'd19;
		y_mem[ 59] = 6'd19;
		y_mem[ 60] = 6'd20;
		y_mem[ 61] = 6'd20;
		y_mem[ 62] = 6'd20;
		y_mem[ 63] = 6'd21;
		y_mem[ 64] = 6'd21;
		y_mem[ 65] = 6'd21;
		y_mem[ 66] = 6'd22;
		y_mem[ 67] = 6'd22;
		y_mem[ 68] = 6'd22;
		y_mem[ 69] = 6'd23;
		y_mem[ 70] = 6'd23;
		y_mem[ 71] = 6'd23;
		y_mem[ 72] = 6'd24;
		y_mem[ 73] = 6'd24;
		y_mem[ 74] = 6'd24;
		y_mem[ 75] = 6'd25;
		y_mem[ 76] = 6'd25;
		y_mem[ 77] = 6'd25;
		y_mem[ 78] = 6'd26;
		y_mem[ 79] = 6'd26;
		y_mem[ 80] = 6'd26;
		y_mem[ 81] = 6'd27;
		y_mem[ 82] = 6'd27;
		y_mem[ 83] = 6'd27;
		y_mem[ 84] = 6'd28;
		y_mem[ 85] = 6'd28;
		y_mem[ 86] = 6'd28;
		y_mem[ 87] = 6'd29;
		y_mem[ 88] = 6'd29;
		y_mem[ 89] = 6'd29;
		y_mem[ 90] = 6'd30;
		y_mem[ 91] = 6'd30;
		y_mem[ 92] = 6'd30;
		y_mem[ 93] = 6'd31;
		y_mem[ 94] = 6'd31;
		y_mem[ 95] = 6'd31;
		y_mem[ 96] = 6'd32;
		y_mem[ 97] = 6'd32;
		y_mem[ 98] = 6'd32;
		y_mem[ 99] = 6'd33;
		y_mem[100] = 6'd33;
		y_mem[101] = 6'd33;
		y_mem[102] = 6'd34;
		y_mem[103] = 6'd34;
		y_mem[104] = 6'd34;
		y_mem[105] = 6'd35;
		y_mem[106] = 6'd35;
		y_mem[107] = 6'd35;
		y_mem[108] = 6'd36;
		y_mem[109] = 6'd36;
		y_mem[110] = 6'd36;
		y_mem[111] = 6'd37;
		y_mem[112] = 6'd37;
		y_mem[113] = 6'd37;
		y_mem[114] = 6'd38;
		y_mem[115] = 6'd38;
		y_mem[116] = 6'd38;
		y_mem[117] = 6'd39;
		y_mem[118] = 6'd39;
		y_mem[119] = 6'd39;
	end

endmodule
