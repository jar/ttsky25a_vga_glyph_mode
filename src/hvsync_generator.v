//`define VGA_640_480_60
//`define VGA_768_576_60
//`define VGA_800_600_60
`define VGA_1024_768_60

// Video sync generator, used to drive a VGA monitor.
// Timing from: http://www.tinyvga.com/vga-timing
// To use:
//  - Wire the hsync and vsync signals to top level outputs
//  - Add a 3-bit (or more) "rgb" output to the top level

module hvsync_generator(clk, reset, mode, hsync, vsync, display_on, hpos, vpos);

	input wire clk;
	input wire reset;
	input wire [1:0] mode;
	output reg hsync, vsync;
	output wire display_on;

	parameter integer NUM_MODE = 4;
	// VGA  640 x 480 @ 60 fps (25.175 MHz)
	// VGA  768 x 576 @ 60 fps (34.96  MHz)
	// VGA  800 x 600 @ 60 fps (40.0   MHz)
	// VGA 1024 x 768 @ 60 fps (65.0   MHz)
	reg [10:0] H_ACTIVE_PIXELS[0:NUM_MODE-1] = {640, 768, 800, 1024}; // horizontal display width
	reg  [9:0] H_FRONT_PORCH  [0:NUM_MODE-1] = { 16,  24,  40,   24}; // horizontal right border
	reg  [9:0] H_SYNC_WIDTH   [0:NUM_MODE-1] = { 96,  80, 128,  136}; // horizontal sync width
	reg  [9:0] H_BACK_PORCH   [0:NUM_MODE-1] = { 48, 104,  88,  160}; // horizontal left border
	reg  [0:0] H_SYNC         [0:NUM_MODE-1] = {  0,   0,   1,    0}; // 0 (-), 1 (+)
	reg  [9:0] V_ACTIVE_LINES [0:NUM_MODE-1] = {480, 576, 600,  768}; // vertical display height
	reg  [9:0] V_FRONT_PORCH  [0:NUM_MODE-1] = { 10,   1,   1,    3}; // vertical bottom border
	reg  [9:0] V_SYNC_HEIGHT  [0:NUM_MODE-1] = {  2,   3,   4,    6}; // vertical sync # lines
	reg  [9:0] V_BACK_PORCH   [0:NUM_MODE-1] = { 33,  17,  23,   29}; // vertical top border
	reg  [0:0] V_SYNC         [0:NUM_MODE-1] = {  0,   1,   1,    0}; // 0 (-), 1 (+)

	// derived constants
	wire [10:0] h_sync_start = H_ACTIVE_PIXELS[mode] + H_FRONT_PORCH[mode];
	wire [10:0] h_sync_end   = h_sync_start + H_SYNC_WIDTH[mode] - 11'd1;
	wire [10:0] h_max        = h_sync_end + H_BACK_PORCH[mode];
	wire  [9:0] v_sync_start = V_ACTIVE_LINES[mode] + V_FRONT_PORCH[mode];
	wire  [9:0] v_sync_end   = v_sync_start + V_SYNC_HEIGHT[mode] - 10'd1;
	wire  [9:0] v_max        = v_sync_end + V_BACK_PORCH[mode];

	output reg [10:0] hpos; // horizontal position counter
	output reg  [9:0] vpos; // vertical position counter

	wire hmaxxed = (hpos == h_max) || reset;	// set when hpos is maximum
	wire vmaxxed = (vpos == v_max) || reset;	// set when vpos is maximum
	wire hactive = (hpos >= h_sync_start) && (hpos <= h_sync_end);
	wire vactive = (vpos >= v_sync_start) && (vpos <= v_sync_end);

	always @(posedge clk)
	begin
		hsync <= hactive ^ ~H_SYNC[mode];
		hpos <= hmaxxed ? 0 : hpos + 1;
		vsync <= vactive ^ ~V_SYNC[mode];
		vpos <= hmaxxed ? (vmaxxed ? 0 : vpos + 1) : vpos;
	end

	// display_on is set when beam is in "safe" visible frame
	assign display_on = (hpos < H_ACTIVE_PIXELS[mode]) && (vpos < V_ACTIVE_LINES[mode]);

endmodule
