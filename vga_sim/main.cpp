#include <iostream>
#include <array>

#include <unistd.h>
#include <SDL2/SDL.h>

#include "Vtt_um_vga_glyph_mode.h"
#include "verilated.h"

// VGA Timings Reference: https://martin.hinner.info/vga/timing.html

#define VGA_HORZ_ACTIVE     640
#define VGA_HORZ_FRONT_PORCH 16
#define VGA_HORZ_SYNC_PULSE  96
#define VGA_HORZ_BACK_PORCH  48

#define VGA_VERT_ACTIVE     480
#define VGA_VERT_FRONT_PORCH 10
#define VGA_VERT_SYNC_PULSE   2
#define VGA_VERT_BACK_PORCH  33

#define VGA_HZ 60
#define VGA_FRAME_CYCLES ((VGA_HORZ_ACTIVE + VGA_HORZ_FRONT_PORCH + VGA_HORZ_SYNC_PULSE + VGA_HORZ_BACK_PORCH) * (VGA_VERT_ACTIVE + VGA_VERT_FRONT_PORCH + VGA_VERT_SYNC_PULSE + VGA_VERT_BACK_PORCH))

struct RGB888_t { uint8_t b, g, r, a; } __attribute__((packed));
union VGApinout_t {
	uint8_t raw;
	struct {
		uint8_t b1    : 1;
		uint8_t g1    : 1;
		uint8_t r1    : 1;
		uint8_t vsync : 1;
		uint8_t b0    : 1;
		uint8_t g0    : 1;
		uint8_t r0    : 1;
		uint8_t hsync : 1;
	} __attribute__((packed)) pin;
};

int main(int argc, char **argv)
{
	std::array<RGB888_t, VGA_HORZ_ACTIVE * VGA_VERT_ACTIVE> fb;

	Verilated::commandArgs(argc, argv);
	Vtt_um_vga_glyph_mode *top = new Vtt_um_vga_glyph_mode;

	// Reset module
	top->clk = 0;
	top->eval();
	top->rst_n = 0;
	top->clk = 1;
	top->eval();
	top->rst_n = 1;

	SDL_Init(SDL_INIT_VIDEO);
	SDL_Window* w = SDL_CreateWindow("Tiny Tapeout VGA", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, VGA_HORZ_ACTIVE, VGA_VERT_ACTIVE, SDL_WINDOW_RESIZABLE);
	SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "best");
	SDL_Renderer* r = SDL_CreateRenderer(w, -1, SDL_RENDERER_ACCELERATED);// | SDL_RENDERER_PRESENTVSYNC);
	if (SDL_RenderSetLogicalSize(r, VGA_HORZ_ACTIVE, VGA_VERT_ACTIVE) != 0) {
		std::cerr << "SDL_RenderSetLogicalSize\n";
		SDL_Quit();
		exit(EXIT_FAILURE);
	}
	SDL_SetRenderDrawColor(r, 0, 0, 0, SDL_ALPHA_OPAQUE);
	SDL_RenderClear(r);
	SDL_Texture* t = SDL_CreateTexture(r, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, VGA_HORZ_ACTIVE, VGA_VERT_ACTIVE);

	int hnum = 0;
	int vnum = 0;
	int polarity = 1;
	bool slow = false;
	bool quit = false;

	while (!quit) {
		int last_ticks = SDL_GetTicks();
		uint8_t ui_in = 0;

		SDL_Event e;
		while (SDL_PollEvent(&e) == 1) {
			if (e.type == SDL_QUIT) {
				quit = true;
			} else if (e.type == SDL_KEYDOWN) {
				switch (e.key.keysym.sym) {
					case SDLK_ESCAPE:
					case SDLK_q:
						quit = true;
						break;
					case SDLK_f:
						static Uint32 mode = SDL_WINDOW_FULLSCREEN_DESKTOP;
						SDL_SetWindowFullscreen(w, mode);
						mode = mode ? 0 : SDL_WINDOW_FULLSCREEN;
						break;
					case SDLK_p: // swap VGA sync polarity
						polarity = polarity ? 0 : 1;
						break;
					case SDLK_s: // toggle slow
						slow = !slow;
					default:
						break;
				}
			}
		}

		auto keystate = SDL_GetKeyboardState(NULL);
		int rst_n = !keystate[SDL_SCANCODE_R];
		ui_in |= keystate[SDL_SCANCODE_0] << 0;
		ui_in |= keystate[SDL_SCANCODE_1] << 1;
		ui_in |= keystate[SDL_SCANCODE_2] << 2;
		ui_in |= keystate[SDL_SCANCODE_3] << 3;
		ui_in |= keystate[SDL_SCANCODE_4] << 4;
		ui_in |= keystate[SDL_SCANCODE_5] << 5;
		ui_in |= keystate[SDL_SCANCODE_6] << 6;
		ui_in |= keystate[SDL_SCANCODE_7] << 7;

		for (int i = 0; i < VGA_FRAME_CYCLES; i++) {

			top->clk = 0;
			top->eval();
			if (rst_n == 0) top->rst_n = 0;
			top->ui_in = ui_in;
			top->clk = 1;
			top->eval();
			if (rst_n == 0) top->rst_n = 1;
			top->ui_in = ui_in;

			VGApinout_t uo_out = {.raw = top->uo_out};

			// h and v blank logic
			if (uo_out.pin.hsync == polarity && uo_out.pin.vsync == polarity) { // XXX Sync polarity positive or negative?
				hnum = -VGA_HORZ_BACK_PORCH;
				vnum = -VGA_VERT_BACK_PORCH;
			}

			// active frame, scaling for 6-bit color
			if ((hnum >= 0) && (hnum < VGA_HORZ_ACTIVE) && (vnum >= 0) && (vnum < VGA_VERT_ACTIVE)) {
				uint8_t rr = 85 * (uo_out.pin.r1 << 1 | uo_out.pin.r0);
				uint8_t gg = 85 * (uo_out.pin.g1 << 1 | uo_out.pin.g0);
				uint8_t bb = 85 * (uo_out.pin.b1 << 1 | uo_out.pin.b0);
				RGB888_t rrggbb = { .b = bb, .g = gg, .r = rr };
				fb[vnum * VGA_HORZ_ACTIVE + hnum] = rrggbb;
			}

			// keep track of encountered fields
			hnum++;
			if (hnum >= VGA_HORZ_ACTIVE + VGA_HORZ_FRONT_PORCH + VGA_HORZ_SYNC_PULSE) {
				hnum = -VGA_HORZ_BACK_PORCH;
				vnum++;
			}

		}

		SDL_RenderClear(r);
		SDL_UpdateTexture(t, NULL, fb.data(), VGA_HORZ_ACTIVE * sizeof(RGB888_t));
		SDL_RenderCopy(r, t, NULL, NULL);
		SDL_RenderPresent(r);

		int ticks = SDL_GetTicks();
		static int last_update_ticks = 0;
		if (ticks - last_update_ticks > 1000) {
			last_update_ticks = ticks;
			std::string fps = "Tiny Tapeout VGA (" + std::to_string((int)1000.0/(ticks - last_ticks)) + " FPS)";
			SDL_SetWindowTitle(w, fps.c_str());
		}
		if (slow) usleep(500000);

	}

	top->final();
	delete top;

	SDL_DestroyRenderer(r);
	SDL_DestroyWindow(w);
	SDL_Quit();

	return EXIT_SUCCESS;
}
