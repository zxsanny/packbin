---
title: "The cpp-m33f row (nRF54L15, Cortex-M33F) is the C++ size and stack bar; the Cortex-M4F rows are gone"
applies_when: "changing cpp/src/core, the arm stage rows of cpp/embedded, or the string-free ECC-free build"
source: "loop 68 (target chip, owner 2026-10-25), loop 84 (AZ-3391), loop 94 (AZ-3479, owner 2026-10-31), loop 95 (AZ-3483)"
---

## Target chip (loop 68)

The target part is the nRF54L15 (owner, 2026-10-25: Cortex-M33F, 256 KB of RAM, about 1.5 MB of NVM, 128 KiB of RAM in a non-secure image, "or higher"), so the C++ byte budgets are chip-scale since loop 68 and byte-shaving of the core has no consumer: the `cpp-m33f` row of the arm stage holds the whole core (codec and error correction on) to 64 KB of flash and 8 KB of stack with pins at the measured 25,760 B and 724 B (`m33f_*` in `cpp/embedded/lib.sh`; the flash pin was 25,720 B until loop 84, when the 40 B of the second translation unit `all_kinds_rounds.cpp` bought the under-500-line split of `all_kinds.cpp`, AZ-3391, owner 2026-10-30, no behaviour change); the Cortex-M4F rows (7,712 B / 540 B) were dropped in loop 94 (owner, 2026-10-31). Later pin raises: [cpp-m33f-pins.md](cpp-m33f-pins.md).

## QEMU and row mechanics

- QEMU `mps2-an505` starts the Cortex-M33 in Secure state: link code at 0x10000000 and RAM at 0x38000000 (`arm/mps2-an505.ld`, that is `cpp/embedded/arm/mps2-an505.ld`); code at the non-secure alias 0 locks up on the first fetch (`Lockup: can't escalate 3 to HardFault`).
- The row compares its packet with `m3-all-kinds.hex` written by `cpp-m3-qemu`, so it runs after that row and a single-row run needs that file in the results folder.
- `target_m33f` shadows `arm_link_common` with a local array for its link helpers.
- Every stub block of `lib.test.sh` names every row of the stage (`target_m33f` too) and `run-parts.test.sh` holds the table order; a new row needs both.
- The stack meter window is 16,384 B, above the 8,192 B ceiling (loop 68).

## The Cortex-M4F rows went in loop 94; the string-free ECC-free image (loop 95)

The Cortex-M4F rows (`cpp-m4f`, `rust-m4f`) went in loop 94 (AZ-3479, owner 2026-10-31): the 8,192 B flash and 2,048 B stack budgets, the pins of 7,712 B and 540 B and the Rust limits of `limits.txt` are gone, and so is the packet comparison of `rust-m33f` with the M4F run. The size and stack bar is the M33F pins (`m33f_*` in `cpp/embedded/lib.sh`, `rust/embedded/limits-m33f.txt`).

The string-free, ECC-free build (`PACKBIN_NO_TEXT`, `PACKBIN_NO_ECC`) is built and run on the host (`make -C cpp no-text-test no-ecc-test`), built for the Uno, and since loop 95 (AZ-3483) run on the Cortex-M33F: `m33f_small_image` in `cpp/embedded/arm.sh` (a step at the end of the `cpp-m33f` row, 2 s) builds the core with both flags together and runs the two host tests unchanged (`-Dmain=` renames their `main`) as one image, run-only with no pin. Its heap and exception checks read the core objects (`check-objects.sh` takes `NM` and `SIZE` for the cross binutils) because the image links newlib stdio and shows one heap symbol, as `vectors.elf` does. An edit that adds code to `cpp/src/core` is held by the M33F pins only.
