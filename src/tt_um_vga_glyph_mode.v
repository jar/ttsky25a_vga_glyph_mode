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
	wire [9:0] g_y9 = pix_y - {yb, 3'b000} - {1'b0, yb, 2'b00};
	wire [3:0] g_y = g_y9[3:0];
	wire hl;

	// Suppress unused signals warning
	wire _unused_ok = &{ena, ui_in, uio_in};

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

	// division by 3
	div3_rom div3(
		.in(pix_y[8:2]),
		.out(yb)
	);

	wire [6:0] r = x[6:0] >> 3;
	wire [5:0] glyph_index = {xb[2] ^ yb[0], xb[0] ^ yb[1], xb[1] ^ yb[2], xb[4] ^ yb[3], xb[3] ^ yb[4]} + {1'b0, xb[5] ^ yb[5], xb[6] ^ yb[0], xb[0] ^ yb[1], xb[1] ^ yb[2]} + r[5:0];

	wire [1:0] a = xb[1:0];
	wire [3:0] b = xb[5:2];
	wire [2:0] d = xb[3:2] + 2'd3;

	wire s = xb[0] ^ xb[1] ^ xb[2] ^ xb[3] ^ xb[4] ^ xb[5] ^ xb[6];
	wire n = xb[1] ^ xb[3] ^ xb[5];

	wire [6:0] v = (counter[9:3] << s) - yb - x_mix;
	wire [3:0] c = {2'b00, a} + d;
	wire [6:0] e = {3'b000, b} << c;
	wire [6:0] f = v[6:0] & e;
	wire [6:0] x = v[6:0] >> a;
	wire [2:0] y = x[2:0] ^ 3'b111;

	wire [5:0] z = (((v[2:0] & 3'b111) == 3'b000) & y == 7) ? 6'b111111 : palette[y];

	wire [5:0] color = ((f != 7'd0) | n) ? palette[0] : z;

	assign RGB = (video_active & hl) ? color : palette[0];
	
	always @(posedge vsync) begin
		if (~rst_n) begin
			counter <= 0;
		end else begin
			counter <= counter + 1;
		end
	end

	// color palette (RRGGBB)
	reg [5:0] palette[0:7]; // RRGGBB
	initial begin
		palette[0] = 6'b000000;
		palette[1] = 6'b000100;
		palette[2] = 6'b001000;
		palette[3] = 6'b001100;
		palette[4] = 6'b001101; //6'b001100;
		palette[5] = 6'b011101; //6'b011100;
		palette[6] = 6'b011110; //6'b011101;
		palette[7] = 6'b101110; //6'b101101;
	end

endmodule
