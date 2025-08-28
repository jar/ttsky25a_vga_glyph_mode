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
	wire [5:0] RGB;
	wire video_active;
	wire [9:0] pix_x;
	wire [9:0] pix_y;

	// TinyVGA PMOD
	assign uo_out = {hsync, RGB[0], RGB[2], RGB[4], vsync, RGB[1], RGB[3], RGB[5]};

	// Unused outputs assigned to 0.
	assign uio_out = 0;
	assign uio_oe  = 0;

	wire [6:0] xb = pix_x[9:3];
	wire [6:0] x_mix = {xb[3], xb[1], xb[4], xb[1], xb[6], xb[0], xb[2]};
	wire [2:0] g_x = pix_x[2:0];
	wire [5:0] yb;
	wire [5:0] g_unused;
	wire [3:0] g_y;
	assign {g_unused, g_y} = pix_y - {yb, 3'b000} - {1'b0, yb, 2'b00};
	wire hl;

	// Suppress unused signals warning
	wire _unused_ok = &{ena, ui_in[7:2], uio_in};

	reg [9:0] counter;

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
		.c(glyph_index),
		.y(g_y),
		.x(g_x),
		.pixel(hl)
	);

	// palette
	wire [5:0] glyph_color;
	palette_rom palettes(
		.cid(y),
		.pid(ui_in[1:0]),
		//.pid(2'b00),
		.color(glyph_color)
	);

	// division by 3
	div3 div3(
		.in(pix_y[8:2]),
		.out(yb)
	);

	// there are 48 glyphs [0,47], so we compute a value in that range
	wire [5:0] glyph_index = {xb[2] ^ yb[0], xb[0] ^ yb[1], xb[1] ^ yb[2], xb[4] ^ yb[3], xb[3] ^ yb[4]} // [0,31]
		+ {1'b0, xb[5] ^ yb[5], xb[6] ^ yb[0], xb[0] ^ yb[1], xb[1] ^ yb[2]} // [0,15]
		+ {2'b00, x[6:3]}; // [0,7]

	wire [1:0] a = xb[1:0];
	wire [3:0] b = xb[5:2];
	wire [2:0] d = xb[3:2] + 2'd3;

	// column features
	wire s = xb[0] ^ xb[1] ^ xb[2] ^ xb[3] ^ xb[4] ^ xb[5] ^ xb[6]; // speed
	wire n = xb[1] ^ xb[3] ^ xb[5]; // on or off

	wire [6:0] v = (counter[9:3] << s) - yb - x_mix;
	wire [3:0] c = {2'b00, a} + d;
	wire [6:0] e = {3'b000, b} << c;
	wire [6:0] f = v & e;
	wire [6:0] x = v >> a;
	wire [2:0] y = x[2:0] ^ 3'b111;
	wire [5:0] black = 6'b000000;
	wire [5:0] white = 6'b111111;

	wire [5:0] z = (((v[2:0] & 3'b111) == 3'b000) & y == 7) ? white : glyph_color;

	wire [5:0] color = ((f != 7'd0) | n) ? black : z;

	assign RGB = (video_active & hl) ? color : black;
	
	always @(posedge vsync) begin
		if (~rst_n) begin
			counter <= 0;
		end else begin
			counter <= counter + 1;
		end
	end

endmodule
