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
	//wire [6:0] x_mix = {x_block[4], x_block[0] ^ x_block[5], x_block[1], x_block[2], x_block[6], x_block[3], x_block[0]};
	wire [6:0] x_mix = {x_block[3], x_block[1], x_block[4], x_block[1], x_block[6], x_block[2], x_block[0]};
	wire [2:0] g_x = pix_x[2:0];
	wire [5:0] y_block;
	//wire [5:0] y_mix = {y_block[0], y_block[0] ^ y_block[4], y_block[1], y_block[2], y_block[5], y_block[3]};
	wire [9:0] g_y9 = pix_y - {y_block, 3'b000} - {1'b0, y_block, 2'b00};
	wire [3:0] g_y = g_y9[3:0];
	wire hl;

	// Suppress unused signals warning
	wire _unused_ok = &{ena, ui_in, uio_in};

	reg [10:0] counter;

	// VGA output
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
	glyphs_rom glyphs(
			.c(glyph_index[4:0]),
			.y(g_y),
			.x(g_x),
			.pixel(hl)
	);

	// division by 3
	div3_rom div3(
		.in(pix_y[8:2]),
		.out(y_block)
	);

	//wire [10:0] r = (x >> d) & 11'd7;
	wire [6:0] r = x[6:0] >> d;
	wire [6:0] glyph_index = {2'b00,
		x_block[2] ^ y_block[0],
		x_block[0] ^ y_block[1],
		x_block[1] ^ y_block[2],
		x_block[4] ^ y_block[3],
		x_block[3] ^ y_block[4]
	} + r[6:0];
	//wire [6:0] glyph_index = r;

	wire [1:0] a = x_block[1:0];
	wire [3:0] b = x_block[5:2];
	wire [2:0] d = x_block[3:2] + 2'd3;

	wire s = x_block[0] ^ x_block[1] ^ x_block[2] ^ x_block[3] ^ x_block[4] ^ x_block[5] ^ x_block[6];
	wire n = x_block[1] ^ x_block[3] ^ x_block[5];

	//wire [6:0] v = (({1'b0, (counter[10:5] << speed[x_block])} >> 2) - y_block - x_mix) >> 1;
	//wire [6:0] v = ((counter[9:3] << speed[x_block]) - y_block - x_mix) >> 0;
	wire [6:0] v = (counter[9:3] << s) - y_block - x_mix;
	//wire [7:0] v = (counter[9:2] << s) - {1'b0, y_block} - {1'b0, x_mix};
	//wire [10:0] v = ((counter[10:0] << s) >> 3) - {5'd0, y_block} - {4'd0, x_mix};
	//wire [6:0] v = ((counter[9:3] - y_block) << x_mix[1:0]) - x_mix;
	//wire [6:0] v = counter[9:3] - y_block - x_mix;
	wire [3:0] c = {2'b00, a} + d;
	wire [6:0] e = {3'b000, b} << c;
	wire [6:0] f = v[6:0] & e;
	wire f1 = f[6] | f[5] | f[4] | f[3] | f[2] | f[1] | f[0];
	//wire [10:0] x = v >> a;
	wire [6:0] x = v >> a;
	//wire [7:0] x = v >> a;
	wire [2:0] y = x[2:0] ^ 3'b111;

	wire [5:0] z = (((v[2:0] & 3'b111) == 3'b000) & y == 7) ? 6'b111111 : RGB[y];

	wire [5:0] color = (f1 | n) ? RGB[0] : z;
	//wire [5:0] color = 6'b111111;

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

	// color palette
	reg [5:0] RGB[0:7];
	initial begin
		RGB[0] = 6'b000000;
		RGB[1] = 6'b000100;
		RGB[2] = 6'b001000;
		RGB[3] = 6'b001100;
		//RGB[4] = 6'b001100;
		//RGB[5] = 6'b011100;
		//RGB[6] = 6'b011101;
		//RGB[7] = 6'b101101;
		RGB[4] = 6'b001101;
		RGB[5] = 6'b011101;
		RGB[6] = 6'b011110;
		RGB[7] = 6'b101110;
	end

	reg speed[0:79];
	initial begin
		speed[ 0] = 0;
		speed[ 1] = 1;
		speed[ 2] = 0;
		speed[ 3] = 1;
		speed[ 4] = 0;
		speed[ 5] = 1;
		speed[ 6] = 0;
		speed[ 7] = 1;
		speed[ 8] = 0;
		speed[ 9] = 1;
		speed[10] = 0;
		speed[11] = 1;
		speed[12] = 0;
		speed[13] = 1;
		speed[14] = 0;
		speed[15] = 1;
		speed[16] = 0;
		speed[17] = 1;
		speed[18] = 0;
		speed[19] = 1;
		speed[20] = 0;
		speed[21] = 1;
		speed[22] = 0;
		speed[23] = 1;
		speed[24] = 0;
		speed[25] = 1;
		speed[26] = 0;
		speed[27] = 1;
		speed[28] = 0;
		speed[29] = 1;
		speed[30] = 0;
		speed[31] = 1;
		speed[32] = 0;
		speed[33] = 1;
		speed[34] = 0;
		speed[35] = 1;
		speed[36] = 0;
		speed[37] = 1;
		speed[38] = 0;
		speed[39] = 1;
		speed[40] = 0;
		speed[41] = 1;
		speed[42] = 0;
		speed[43] = 1;
		speed[44] = 0;
		speed[45] = 1;
		speed[46] = 0;
		speed[47] = 1;
		speed[48] = 0;
		speed[49] = 1;
		speed[50] = 0;
		speed[51] = 1;
		speed[52] = 0;
		speed[53] = 1;
		speed[54] = 0;
		speed[55] = 1;
		speed[56] = 0;
		speed[57] = 1;
		speed[58] = 0;
		speed[59] = 1;
		speed[60] = 0;
		speed[61] = 1;
		speed[62] = 0;
		speed[63] = 1;
		speed[64] = 0;
		speed[65] = 1;
		speed[66] = 0;
		speed[67] = 1;
		speed[68] = 0;
		speed[69] = 1;
		speed[70] = 0;
		speed[71] = 1;
		speed[72] = 0;
		speed[73] = 1;
		speed[74] = 0;
		speed[75] = 1;
		speed[76] = 0;
		speed[77] = 1;
		speed[78] = 0;
		speed[79] = 1;
	end

endmodule
