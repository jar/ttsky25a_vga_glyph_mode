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
	wire [5:0] y_block;// = y_mem[pix_y[8:2]];
	wire [9:0] g_y9 = pix_y - {y_block, 3'b000} - {1'b0, y_block, 2'b00};
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
		.out(y_block)
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

endmodule
