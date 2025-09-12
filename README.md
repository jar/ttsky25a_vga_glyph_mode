![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout VGA Glyph Mode

The name is a play on the VGA Text Mode, but this project uses glyphs seen in
[The Matrix Digital Rain](https://www.youtube.com/watch?v=SneR61OG4ZI) -- a
brilliant effect from the best science fiction movie since 1999.

![animated VGA output](docs/optimized.gif)

This began as an entry into the Tiny Tapeout 08 Demoscene competition as a
single tile design. A number of improvements have been made including:

- Four different display resolutions (from 640x480 to 1024x768)
  - Up to 2.56x more pixels!
  - The hvsync signals have been updated with correct polarity
- Upon reset, the glyphs appear to fall from the top of the display
- Smoother rain (fast columns no longer jump two glyphs at a time)
- There are changing glyphs (periodically alternate)
- Added 6 more glyphs from the movie
- A module has been eliminated
- The [Verilator VGA simulation](vga_sim) now supports:
  - Multiple signaling modes
  - Optional animated GIF output
  - Fullscreen display
  - ...and more!

[Read the documentation](docs/info.md) to learn how to use the circuit.

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper
than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.
