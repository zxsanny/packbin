# Embedded stage of the heap-free Rust API

Proves that `packbin::nostd` (built with `default-features = false`) links and runs on a Cortex-M4F and on a
Cortex-M33F with no heap and no panic path, and prints its flash and stack.

```
rust/embedded/run.sh host    # static libraries with the host cargo, then the image stage in Docker
rust/embedded/run.sh libs    # only the libraries (needs: rustup target add thumbv7em-none-eabihf thumbv8m.main-none-eabihf)
rust/embedded/run.sh image   # inside packbin-embedded (what docker-compose.test.yml runs)
```

- `probe/` is a `staticlib` crate with `extern "C"` entry points (a 14-field route pack and unpack, the golden
  fixture decode). `main.cpp` is the image's `main`: it calls them and measures the stack of each call.
- The image reuses the C++ stage's startup code, linker script, stack meter, QEMU runner and report rows
  (`cpp/embedded/`), so Rust and C++ figures come from one method. A second image without the library gives the
  meter's overhead and the flash baseline.
- `feature-sets.txt` lists the feature sets built and reported; `limits.txt` the flash and stack limits per set
  (`-` is none; since 2026-10-23 every set has one: the owner set text, ecc and session at the figure measured in loop 65 plus 5%, `checks.test.sh` fails on a set without numbers). The stage fails above a limit and prints the figure and the limit.
- `checks.sh` finds heap symbols (`__rust_alloc`, `malloc`, ...) and panic paths (`core::panicking`,
  `panic_bounds_check`, `unwrap_failed`, slice-length failures) in the linked image; `checks.test.sh` tests it
  without a toolchain. The target `rust-mutants` links probes with a seeded panic path and a seeded heap call
  (`seed_panic`, `seed_heap`) and fails unless the checks catch both.
- A panic path comes from `unwrap`, `expect`, indexing, `slice::reverse`, `copy_from_slice`, `split_at_mut` and any `chunks*` (they link a division and a panic at opt-level z); `nostd` uses
  `get`, checked arithmetic and zipped copies, and denies the clippy lints that find the rest.
- The `frame` set (AZ-3203) builds the crate with `frame` only: its probe seals the first worked example of frame mode and opens it with a replay window, then computes and verifies a MAC-only tag. A set whose features lack `session` must link no stream-session symbol (`stream_hits` in `checks.sh`); the probe loads its session in place (`Session::frame_unloaded`, `load_frame_in_place`), because a copy of the 600-byte session cost 560 B of stack more.
- The `rust-m33f` row (AZ-3231, loop 70) runs the same five sets on the Cortex-M33F of the owner's target part, the nRF54L15, through `thumbv8m.main-none-eabihf` libraries (built into `build-m33f/`, next to the M4F ones in `build/`), the C++ stage's `mps2-an505` linker script (Secure state: code at 0x10000000, RAM at 0x38000000) and QEMU `mps2-an505`. Each set must stay under the chip-scale ceilings of `cpp/embedded/lib.sh` (65,536 B of flash, 8,192 B of stack; owner, 2026-10-25) and under its pin in `limits-m33f.txt` (the figures measured with Rust 1.98.1, the toolchain of the CI job; `PACKBIN_RUST_EMBEDDED_LIMITS_M33F` names another file). It reuses `rust_row` with the M4F row's checks and compares each set's `ROUTE_HEX` with the M4F run, so it runs after `rust-m4f`. The seeded-defect mutants stay on the M4F row: the link checks read symbol names, not the architecture.
