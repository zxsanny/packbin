# Acceptance criteria — Rust Cortex-M33F row (loop 70)

Inherited baseline: the Rust embedded stage criteria of AZ-2751 (heap-free, no panic path, no static RAM, golden fixture decodes on the image, flash and stack limits per feature set) and the chip-scale ceilings of AZ-3189 (owner, 2026-10-25: 64 KB of flash, 8 KB of stack).

**AC-1: Libraries for the Cortex-M33F** — `rust/embedded/run.sh libs` builds every feature set (base, text, ecc, session, frame) of the probe for `thumbv8m.main-none-eabihf` into a build folder of its own, next to the `thumbv7em-none-eabihf` libraries; the M4F libraries and their paths are unchanged.
**AC-2: The row runs on a Cortex-M33 machine** — a row `rust-m33f` links each set into the image of the C++ stage built with `-mcpu=cortex-m33 -mfloat-abi=hard -mfpu=fpv5-sp-d16` and the `mps2-an505` linker script (code 0x10000000, RAM 0x38000000), runs it on QEMU `mps2-an505`, and every set reports `FAILURES` 0 and `GOLDEN_OK` 1; the route pack and unpack and the `pb_rs_extra` round trip of each set pass.
**AC-3: Same link checks** — for every set on the M33F image: no heap symbol, no panic path, no stream-session symbol without the `session` feature, and the library adds 0 B of `.data` and `.bss`.
**AC-4: Same bytes as the M4F image** — the route packet and the golden decode of a set on the M33F image equal the M4F image's (the same `ROUTE_HEX`).
**AC-5: Ceilings and pins** — per set, flash at most 65,536 B and net stack at most 8,192 B (`m33f_flash_budget`, `m33f_stack_budget` of `cpp/embedded/lib.sh`); and per-set pins in `limits-m33f.txt` equal to the figures measured on HEAD with the toolchain of CI (Rust 1.98), the row failing above a pin, naming the figure, the set and the pin.
**AC-6: The ceilings and pins bite** — a pin one byte lower, or a ceiling below the figure, fails the row (smoke through `PACKBIN_RUST_EMBEDDED_LIMITS_M33F`, like the M4F smoke).
**AC-7: M4F row unchanged** — `rust-m4f` and `rust-mutants` pass with the same limits file and the same figures as before.
**AC-8: Harness and CI** — `run.sh libs` and `host` build both targets; the `embedded-arm` job installs the `thumbv8m.main-none-eabihf` target; `checks.test.sh`, `run-parts.test.sh` and the publish-jobs tests that read the workflow pass; `limits-m33f.txt` is checked like the M4F limits (every set has numbers).
**AC-9: Notes** — `rust/embedded/README.md`, the Rust description in `_docs/02_document`, `tests.md`, and a line in `_docs/AGENT_GOTCHAS.md` with the chip, ceilings, pins, secure aliases and the toolchain the pins come from.
**AC-10: Source untouched** — 0 changes in `rust/src` and in `cpp/src/core`, `cpp/include`; the probe crate changes only if a set needs it.
