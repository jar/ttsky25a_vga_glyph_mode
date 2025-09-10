#include <iostream>
#include <array>
#include <cstdint>
#include <climits>

#include <SDL2/SDL.h>

#include "Vtt_um_vga_glyph_mode.h"
#include "verilated.h"
#include "vga_timings.hpp"
#include "gif.h"

struct RGB888_t { uint8_t b, g, r, a; } __attribute__((packed));
union VGApinout_t {
	uint8_t pins;
	struct { // 6-bit color with sync
		uint8_t r1    : 1;
		uint8_t g1    : 1;
		uint8_t b1    : 1;
		uint8_t vsync : 1;
		uint8_t r0    : 1;
		uint8_t g0    : 1;
		uint8_t b0    : 1;
		uint8_t hsync : 1;
	} __attribute__((packed));
};

int main(int argc, char **argv)
{
	// Command line options
	static Uint32 fullscreen = 0;
	bool polarity = false;
	bool slow = false;
	bool gif = false;
	int gif_frames = INT_MAX;

	for (int i = 1; i < argc; i++) {
		char* p = argv[i];
		if (!strcmp("--fullscreen", p)) fullscreen = fullscreen ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP;
		else if (!strcmp("--polarity", p)) polarity = !polarity;
		else if (!strcmp("--slow", p)) slow = !slow;
		else if (!strcmp("--gif", p)) {
			gif = !gif;
			if (i + 1 < argc) gif_frames = atoi(argv[++i]);
		} else {
			printf("Command Line   | [Keyboard]\n");
			printf("  --fullscreen | [F]\tToggles SDL window size (default: %s)\n", fullscreen ? "maximized" : "minimized");
			printf("  --polarity   | [P]\tToggles the VGA polarity sync high/low (default: %s)\n", polarity ? "true" : "false");
			printf("  --slow       | [S]\tToggles the displayed frame rate (default: %s)\n", slow ? "true" : "false");
			printf("  --gif [#]         \tSaves animated GIF (default: %s [%d])\n", gif ? "true" : "false", gif_frames);
			printf("               | [Q]\tQuits/Escapes (stops GIF if enabled).\n");
			return 0;
		}
	}

	// Select the VGA timings from the list
	//constexpr vga_timing vga = vga_timings[VGA_640_480_60];
	//constexpr vga_timing vga = vga_timings[VGA_768_576_60];
	//constexpr vga_timing vga = vga_timings[VGA_800_600_60];
	constexpr vga_timing vga = vga_timings[VGA_1024_768_60];
	std::array<RGB888_t, vga.horz_active_frame * vga.vert_active_frame> fb{};

	// GIF output
	GifWriter g;
	int bitdepth = 6;
	float frame_time = vga.frame_cycles() / (vga.clock_mhz * 1000.);
	int delay = ceil(frame_time / 10.f);
	if (!delay) delay = 1;
	if (gif) {
		printf("frame_time = %f ms (rounded up to nearest 100th second = %d)\n", frame_time, delay);
		GifBegin(&g, "output.gif", vga.horz_active_frame, vga.vert_active_frame, delay);
	}

	Verilated::commandArgs(argc, argv);
	Vtt_um_vga_glyph_mode *top = new Vtt_um_vga_glyph_mode;

	SDL_Init(SDL_INIT_VIDEO);
	SDL_Window* w = SDL_CreateWindow("Tiny Tapeout VGA", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, vga.horz_active_frame, vga.vert_active_frame, SDL_WINDOW_RESIZABLE | fullscreen);
	SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "best");
	SDL_Renderer* r = SDL_CreateRenderer(w, -1, SDL_RENDERER_ACCELERATED);// | SDL_RENDERER_PRESENTVSYNC);
	if (SDL_RenderSetLogicalSize(r, vga.horz_active_frame, vga.vert_active_frame)) {
		std::cerr << "ERROR: SDL_RenderSetLogicalSize\n";
		exit(EXIT_FAILURE);
	}
	SDL_SetRenderDrawColor(r, 0, 0, 0, SDL_ALPHA_OPAQUE);
	SDL_RenderClear(r);
	SDL_Texture* t = SDL_CreateTexture(r, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, vga.horz_active_frame, vga.vert_active_frame);

	// Main single frame loop
	bool quit = false;
	while (!quit) {
		static int frame = 0;
		int last_ticks = SDL_GetTicks();
		uint8_t ui_in = 0;

		SDL_Event e;
		while (SDL_PollEvent(&e)) {
			if (e.type == SDL_QUIT) {
				quit = true;
			} else if (e.type == SDL_KEYDOWN) {
				switch (e.key.keysym.sym) {
					case SDLK_ESCAPE:
					case SDLK_q:
						quit = true;
						break;
					case SDLK_f: // toggle fullscreen window
						fullscreen = fullscreen ? 0 : SDL_WINDOW_FULLSCREEN_DESKTOP;
						SDL_SetWindowFullscreen(w, fullscreen);
						break;
					case SDLK_p: // toggle VGA sync polarity
						polarity = !polarity;
						break;
					case SDLK_s: // toggle slow
						slow = !slow;
					default:
						break;
				}
			}
		}

		auto k = SDL_GetKeyboardState(NULL);
		auto rst_n = k[SDL_SCANCODE_R];
		static bool rst_init = false;
		if (!rst_init) { rst_n = rst_init = true; } // reset on first clock cycle
		ui_in |= k[SDL_SCANCODE_0] << 0;
		ui_in |= k[SDL_SCANCODE_1] << 1;
		ui_in |= k[SDL_SCANCODE_2] << 2;
		ui_in |= k[SDL_SCANCODE_3] << 3;
		ui_in |= k[SDL_SCANCODE_4] << 4;
		ui_in |= k[SDL_SCANCODE_5] << 5;
		ui_in |= k[SDL_SCANCODE_6] << 6;
		ui_in |= k[SDL_SCANCODE_7] << 7;

		static int hnum = 0;
		static int vnum = 0;
		// Intra-frame verilator cycles
		for (int cycle = 0; cycle < vga.frame_cycles(); cycle++) {
			// set inputs and tick-tock
			top->clk = 0;
			top->eval();
			if (rst_n) top->rst_n = 0;
			top->ui_in = ui_in;
			top->clk = 1;
			top->eval();
			if (rst_n) top->rst_n = 1;
			top->ui_in = ui_in;

			VGApinout_t uo_out{top->uo_out};

			// h and v blank/sync logic
			bool sync = uo_out.hsync == vga.horz_sync_pol && uo_out.vsync == vga.vert_sync_pol;
			if (sync || (!sync && polarity)) {
				hnum = -vga.horz_back_porch;
				vnum = -vga.vert_back_porch;
			}

			// active frame, scaling for 6-bit color
			if ((hnum >= 0) && (hnum < vga.horz_active_frame) && (vnum >= 0) && (vnum < vga.vert_active_frame)) {
				uint8_t rr = 85 * (uo_out.r1 << 1 | uo_out.r0);
				uint8_t gg = 85 * (uo_out.g1 << 1 | uo_out.g0);
				uint8_t bb = 85 * (uo_out.b1 << 1 | uo_out.b0);
				RGB888_t rrggbb = { .b = bb, .g = gg, .r = rr };
				fb[vnum * vga.horz_active_frame + hnum] = rrggbb;
			}

			// keep track of encountered fields
			hnum++;
			if (hnum >= vga.horz_active_frame + vga.horz_front_porch + vga.horz_sync_pulse) {
				hnum = -vga.horz_back_porch;
				vnum++;
			}
		}

		SDL_RenderClear(r);
		SDL_UpdateTexture(t, NULL, fb.data(), vga.horz_active_frame * sizeof(RGB888_t));
		SDL_RenderCopy(r, t, NULL, NULL);
		SDL_RenderPresent(r);

		int ticks = SDL_GetTicks();
		static int last_update_ticks = 0;
		if (ticks - last_update_ticks > 500) {
			last_update_ticks = ticks;
			std::string fps = "Tiny Tapeout VGA (" + std::to_string((int)1000.0/(ticks - last_ticks)) + " FPS)";
			SDL_SetWindowTitle(w, fps.c_str());
		}
		if (gif) {
			GifWriteFrame(&g, (uint8_t*)fb.data(), vga.horz_active_frame, vga.vert_active_frame, delay, bitdepth);
			frame++;
			if (frame == gif_frames) quit = true;
		}
		if (slow) usleep(250000); // ~4 fps

	}

	if (gif) GifEnd(&g);

	top->final();
	delete top;

	SDL_DestroyRenderer(r);
	SDL_DestroyWindow(w);
	SDL_Quit();

	return EXIT_SUCCESS;
}
