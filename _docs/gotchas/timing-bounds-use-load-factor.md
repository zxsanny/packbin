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
- Dart `test/support/timing.dart` (added in loop 113: reference loop 0.020 s idle, factor 1 to 8, mean of 5, re-measured when a check fails; `test/limits/colliding_keys_test.dart` still uses fixed `lessThan(1000)` bounds and failed once at load 50)

The factor is a CPU reference loop timed beside the check (at least 1, at most 8; Python and TypeScript take the mean of 5 runs, the others the smallest of 3, and Rust, Go, Swift and C++ also re-measure over the length of the section when a check fails; each helper holds the idle time of its loop, the smallest of many runs); the nominal bound still decides on an idle host. A new timing check calls the helper, and `cpp/Makefile` does not list `load_factor.hpp`, so `make -C cpp clean` after editing it.
