---
title: "A wall-clock assertion uses the package's load-factor helper, never a fixed bound"
applies_when: "writing or changing a wall-clock (speed) check in any package's tests"
source: "loop 43 (AZ-2723), loop 113 (Dart helper)"
---

A wall-clock assertion in a test uses the package's load factor, never a fixed bound (loop 43, AZ-2723; the host runs other sessions at load 20 to 200 and fixed 1 s bounds failed even on the serial retry).

The helpers:

- Python `tests/timing_support.py` (`bound`, `assert_within`)
- TypeScript `tests/support/timing.ts` (`bound`, `assertWithin`)
- C# `tests/Timing.cs` (`Timing.Bound`)
- Java `Timing.java` (`Timing.bound`)
- Rust `src/timing_support.rs` (`load_factor`, `assert_within`)
- Go `timing_test.go` (`loadFactor`, `assertWithin`)
- Swift `LoadFactor.swift` (`bound`, `expectWithin`)
- C++ `tests/core/load_factor.hpp` (`load_factor::bound`, `expect_within`)
- Dart `test/support/timing.dart` (added in loop 113: reference loop 0.020 s idle, factor 1 to 8, mean of 5, re-measured when a check fails; since loop 121 (AZ-4260) every Dart wall-clock bound uses it, `test/limits/colliding_keys_test.dart` and the per-unpack 1 s bound of the hostile and fuzz loops included (`overLoadBound`: no load measurement unless a call is over its nominal bound); the fixed `lessThan(1000)` failed once at load 50)

The factor is a CPU reference loop timed beside the check (at least 1, at most 8; Python and TypeScript take the mean of 5 runs, the others the smallest of 3, and Rust, Go, Swift and C++ also re-measure over the length of the section when a check fails; each helper holds the idle time of its loop, the smallest of many runs); the nominal bound still decides on an idle host. A new timing check calls the helper, and `cpp/Makefile` does not list `load_factor.hpp`, so `make -C cpp clean` after editing it.

A sanitizer build of the C++ host suite (`make -C cpp CXX=clang++ sanitizer-test`: ASan and UBSan, clang; GCC 16 cannot build the suite with `-fsanitize=undefined`) prints each `expect_within` as `TIMING (sanitizer build, not asserted)` and asserts nothing, because a sanitizer slows memory work that the load factor cannot see (loop 114: the AC-7 text check missed its 1 s bound by 3 to 13 ms in two runs of three); the plain builds keep every bound (loop 121, AZ-4261, decision D15). The hostile hang guard has no limit in that build, so a CI job running it needs its own timeout: since loop 122 (AZ-4278) the `cpp` suite runs it with Debian's `clang-19` under `timeout 600`. That clang refused folds over 255+ members (fixed in loop 123, AZ-4279: the core sums and copies members through array expansions, no `-fbracket-depth`) and reports `memcpy` / `memcmp` from an empty vector's null `data()`, which Apple's clang on the Mac does not: run it in the container before calling a sanitizer change green.
