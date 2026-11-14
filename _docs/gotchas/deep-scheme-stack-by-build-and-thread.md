---
title: "256 nested levels fit a release build and a main thread; a debug build on a small thread can overflow (Rust map API, Swift)"
applies_when: "writing or running a test that builds, packs or unpacks a scheme nested near the 256-level limit, or answering a stack overflow report on a deep scheme"
source: "loop 126 (AZ-4300 Swift, AZ-4302 Rust)"
---

The depth limit (contract `scheme-depth.md`, 256 levels) is checked first and without recursion, but a scheme at 256 is still packed and unpacked by recursive walks. Measured in loop 126:

- **Rust map API, debug:** pack and unpack use about 11 KiB of stack per level, so 256 levels need about 3 MiB; a 2 MiB test thread overflows above about 145 levels (140 ok, 150 fails). Release is fine to 5,000. `run-suite.sh` sets `RUST_MIN_STACK=8388608` in the Rust case, so the 256-level round trips and the two pack hostile cases run in CI; without it they print `skipped` with the reason (`walk_fits_stack()`).
- **Swift:** a release build fits 256 levels of every kind on a 256 KiB thread (`flags` on 512 KiB); a debug build needs 640 KiB (`flags` between 1 and 1.5 MiB), so it overflows on a 512 KiB Swift-concurrency thread. The 256-level tests are `@MainActor` (8 MiB).
- **C#, Java, Go, TypeScript, Dart, Python, C++:** 256 levels of every kind built, packed and unpacked at the host's default stack (Python worst case about 397 levels at the default recursion limit).

Shrinking the debug frames (`bindAll` in Swift, `pack_one` / `unpack_one` in Rust) is a separate hygiene item.
