# Blackbox tests 23 — Rust Cortex-M33F row (loop 70)

## FT-X-161: five feature sets on the Cortex-M33F image

Embedded stage `rust-m33f` (`rust/embedded`, AZ-3231): the probe built for `thumbv8m.main-none-eabihf` with Rust 1.98.1 is linked into the C++ stage's image (`-mcpu=cortex-m33 -mfloat-abi=hard -mfpu=fpv5-sp-d16`, `mps2-an505.ld`: code 0x10000000, RAM 0x38000000) and run on QEMU `mps2-an505`. Per set: `FAILURES 0`, `GOLDEN_OK 1`, `ROUTE_HEX` equal to the Cortex-M4F run, no heap symbol, no panic path, no stream-session symbol without `session` (that check and the `session` set retired in loop 74, ADR 009), 0 B of `.data` and `.bss`. Figures (flash / net stack): base 15,132 B / 456 B, text 27,268 / 2,736, ecc 18,764 / 744, session 18,884 / 1,528, frame 20,236 / 1,752; each under 65,536 B / 8,192 B and equal to its pin in `limits-m33f.txt`. CI figures are read after the push.

## FT-X-162: the pins bite

`limits-m33f.txt` with `frame 20235`: the row prints `NOTE FAIL frame: flash 20236 B over 20235 B` and the stage reports `1 target(s) failed`. `checks.test.sh`: every set of `feature-sets.txt` has numeric M33F pins, a `-` pin is caught, no pin is above 65,536 B or 8,192 B.
