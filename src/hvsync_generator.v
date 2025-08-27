`ifndef HVSYNC_GENERATOR_H
`define HVSYNC_GENERATOR_H
`define VGA_640_480_60

// Video sync generator, used to drive a VGA monitor.
// Timing from: https://en.wikipedia.org/wiki/Video_Graphics_Array
// To use:
//  - Wire the hsync and vsync signals to top level outputs
//  - Add a 3-bit (or more) "rgb" output to the top level

module hvsync_generator(clk, reset, hsync, vsync, display_on, hpos, vpos);

	input clk;
	input reset;
	output reg hsync, vsync;
	output display_on;

`ifdef VGA_640_480_60 // VGA 640 x 480 @ 60 fps (25.175 MHz)
	parameter H_ACTIVE_PIXELS = 640; // horizontal display width
	parameter H_FRONT_PORCH   =  16; // horizontal right border
	parameter H_SYNC_WIDTH    =  96; // horizontal sync width
	parameter H_BACK_PORCH    =  48; // horizontal left border
	parameter H_SYNC          =   0; // 0 (-), 1 (+)
	parameter V_ACTIVE_LINES  = 480; // vertical display height
	parameter V_FRONT_PORCH   =  10; // vertical bottom border
	parameter V_SYNC_HEIGHT   =   2; // vertical sync # lines
	parameter V_BACK_PORCH    =  33; // vertical top border
	parameter V_SYNC          =   0; // 0 (-), 1 (+)
`else
`ifdef VGA_800_600_60 // VGA 800 x 600 @ 60 fps (40.0 MHz)
	parameter H_ACTIVE_PIXELS = 800; // horizontal display width
	parameter H_FRONT_PORCH   =  40; // horizontal right border
	parameter H_SYNC_WIDTH    =  88; // horizontal sync width
	parameter H_BACK_PORCH    = 128; // horizontal left border
	parameter H_SYNC          =   1; // 0 (-), 1 (+)
	parameter V_ACTIVE_LINES  = 600; // vertical display height
	parameter V_FRONT_PORCH   =   1; // vertical bottom border
	parameter V_SYNC_HEIGHT   =   4; // vertical sync # lines
	parameter V_BACK_PORCH    =  23; // vertical top border
	parameter V_SYNC          =   1; // 0 (-), 1 (+)
`else
`ifdef VGA_640_350_85 // VGA 640 x 350 @ 85 fps (31.5 MHz)
	parameter H_ACTIVE_PIXELS = 640; // horizontal display width
	parameter H_FRONT_PORCH   =  32; // horizontal right border
	parameter H_SYNC_WIDTH    =  64; // horizontal sync width
	parameter H_BACK_PORCH    =  96; // horizontal left border
	parameter H_SYNC          =   1; // 0 (-), 1 (+)
	parameter V_ACTIVE_LINES  = 350; // vertical display height
	parameter V_FRONT_PORCH   =  32; // vertical bottom border
	parameter V_SYNC_HEIGHT   =   3; // vertical sync # lines
	parameter V_BACK_PORCH    =  60; // vertical top border
	parameter V_SYNC          =   0; // 0 (-), 1 (+)
`endif
`endif
`endif

	// derived constants
	localparam H_SYNC_START   = H_ACTIVE_PIXELS + H_FRONT_PORCH;
	localparam H_SYNC_END     = H_SYNC_START + H_SYNC_WIDTH - 1;
	localparam H_MAX          = H_SYNC_END + H_BACK_PORCH;
	localparam V_SYNC_START   = V_ACTIVE_LINES + V_FRONT_PORCH;
	localparam V_SYNC_END     = V_SYNC_START + V_SYNC_HEIGHT - 1;
	localparam V_MAX          = V_SYNC_END + V_BACK_PORCH;

	output reg [$clog2(H_MAX)-1:0] hpos; // horizontal position counter
	output reg [$clog2(V_MAX)-1:0] vpos; // vertical position counter

	wire hmaxxed = (hpos == H_MAX) || reset;	// set when hpos is maximum
	wire vmaxxed = (vpos == V_MAX) || reset;	// set when vpos is maximum
	wire hactive = (hpos >= H_SYNC_START) && (hpos <= H_SYNC_END);
	wire vactive = (vpos >= V_SYNC_START) && (vpos <= V_SYNC_END);

	always @(posedge clk)
	begin
		hsync <= hactive ^ ~H_SYNC;
		hpos <= hmaxxed ? 0 : hpos + 1;
		vsync <= vactive ^ ~V_SYNC;
		vpos <= hmaxxed ? (vmaxxed ? 0 : vpos + 1) : vpos;
	end

	// display_on is set when beam is in "safe" visible frame
	assign display_on = (hpos < H_ACTIVE_PIXELS) && (vpos < V_ACTIVE_LINES);

endmodule

`endif
