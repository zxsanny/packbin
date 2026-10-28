# Batch Report

**Batch**: 1 (loop 79)
**Tasks**: AZ-3356_frame_ring_number_ranges, AZ-3357_rust_test_build_warnings (two workers at once, disjoint files)
**Date**: 2026-10-28

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3356_frame_ring_number_ranges | Done | 13 (8 drivers, rows, README, checker, 2 test scripts) | real ring `refusals <lang>: 43 rows, 0 mismatched` x 8, `64 pairs, mismatched: 0`; driver script 132 of 132 (was 44); self-test all passed (5 new cases) | Java epoch (Discovered 1) |
| AZ-3357_rust_test_build_warnings | Done | 10 (4 Rust sources, 3 tests, test support, `run-suite.sh`, `run-suite.test.sh`) | 0 `warning:` lines in all 9 sets; `run-suite.test.sh` all checks passed; Rust suite 96 `test result` lines equal to HEAD, 0 failed | `take` in `counters.rs` (Discovered 2); step switched to `cargo check --tests` (Discovered 3) |

## Code Review Verdict: not run per batch (owner preference: one total review and one step-11 run per loop)

The parent read both diffs before the commit: one digit-by-digit number reader per driver (no wrap, no overflow), the loader's `RANGES` table, `show()` with `... and N more`, the Rust cfgs equal to their callers'.

## Test Suite

- `ring-frame.sh` (all 8 languages, fresh work dir, parent): `refusals <lang>: 43 rows, 0 mismatched` x 8, `ring-frame: 64 pairs, mismatched: 0`, 3 s with built drivers.
- `ring-frame-drivers.test.sh` (parent): `all passed (8 languages, 132 checks)`, 7 s.
- `ring-frame.test.sh` (parent): `all passed`, 10 s; new cases `refusals-7`, `pair-6`, `refusals-5`, `row-dir-256`, `row-out-len-65536`.
- AZ-3356 AC-3 (worker): the new driver script against the cb6759b drivers: 54 of 132 cases FAIL (direction 256 in all 8; `-1` in C#, Python, Java; tag length 256 in 7; kind 256 in 6; `clear_len`, `out_len` 65536 and `n` 256 in all 8; epoch 4294967296 in TypeScript, Python, Go), the 44 old checks pass; the new self-test cases fail 4 of 5 against the cb6759b checker (the no-line control passes).
- AZ-3357 AC-8 (parent, host Rust 1.98.1): `cargo check --tests` and `cargo test --no-run` print 0 `warning:` lines in none, alloc, text, ecc, text,ecc, frame, text,ecc,frame, default and all features; on cb6759b `check --tests` of `frame` prints the 3 warnings.
- AZ-3357 AC-10 (parent): `#![cfg(feature = "std")]` removed from `rust/tests/bound_names_tests.rs` in a scratch copy: `cargo check --no-default-features --tests` exits 101 with `unresolved imports` in `bound_names_tests`; the worker showed the same through `run-suite.sh rust` (`FAIL,rust test build of feature set none failed`).
- AZ-3357 AC-11 / AC-12, cold on 4 CPUs (`docker run --cpus 4 rust:1.98 run-suite.sh rust`, fresh target, parent): HEAD 185 s; with `cargo test --no-run` for the 9 sets 249 s (+64 s); with `cargo check --tests` 193 s (+8 s; the 9 checks about 10 s together). `test result` lines: 96 in each, identical counts, 0 failed.
- CI parity (parent): `g++ -std=c++17 -O2 -Wall -Wextra -Werror` in `gcc:16` (driver refuses direction 256 with `frame line 1`); `gofmt -l` empty and `go vet` in `golang:1.27`; `shellcheck -S warning` clean on `run-suite.sh`, `run-suite.test.sh` (and, worker, the two ring scripts); `loop-tests.test.sh`, `ring-wiring.test.sh`, `ring-wiring-rows.test.sh`, `ring-lib.test.sh`, `publish-jobs.test.sh`, `report-row.test.sh` all pass; Swift driver in `swift:6.3.3` `--static-swift-stdlib` (worker and parent: `Build complete!`, 49 s).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The Java package takes the epoch as an `int`, so an in-range epoch above 2,147,483,647 (the top row 4,294,967,295) has no value to pass unchanged | AZ-3356 AC-2, AC-5; rule "in range goes to the package unchanged" | the Java driver prints `BadValue` itself above `Integer.MAX_VALUE` (the package's answer for any epoch above 0xFFFFFF), as the Rust driver does for directions 0 and 4 (owner U1, loop 78); written in `fixtures/frame/README.md`. Alternative: lower the epoch top to 2,147,483,647 for all drivers | unclear (owner decision) |
| 2 | The default test build warns about `take` (`rust/src/session_core/counters.rs:18`), called only by the two frame test modules; the intake probe had not built the default set and blamed `from_hex` | AZ-3357 AC-8 | `#[cfg(feature = "frame")]` on `take` (parent, outside the worker's list); `problem.md` and the spec corrected | clear (AC-8: 0 warnings in the default set) |
| 3 | `cargo test --no-run` for the 7 no-std sets costs +64 s cold on 4 CPUs, on `suites (csharp rust)`, the longest CI job (286 s on the loop 78 push) | AZ-3357 AC-9, loop AC-12 (+60 s) | `cargo check --tests`: same compile errors and lints (AC-8, AC-10 shown with it), no code generation; the owner accepted `--no-run` by name, so the change is reported | clear (AC-12 bound) |
| 4 | Java and C++ read `out_len` only after a successful load, so a load refusal hid a bad `out_len`; the C++ MAC buffer was 32 bytes under a span of up to `n` bytes | AZ-3356 AC-1 | both read every number first; C++ buffer 255 (the top of `n`) | clear |
| 5 | A `seal` or `mac` row the reference refuses (a seal row with direction 4) crashes `ring_frame.py` with an `ff.Fault` traceback that does not name the row (exit 1); before this loop | none | leftover for a later loop: catch `ff.Fault` there and name the row | clear (out of scope here) |
| 6 | `run_lang` rebuilds the C# and C++ drivers only when the binary is missing, so a kept `PACKBIN_RING_WORK` runs old drivers after a driver edit; a `git archive` copy needs its root named `packbin` (Swift package identity) and its own Java, Go and Swift build paths | none | gotcha lines at loop close; step 11 uses a fresh work dir | clear |

## Commit

`[AZ-3356] [AZ-3357] Ring number ranges; warning-free Rust test builds`. Body: one line + `Loop: 79`.

## Next Batch: All tasks complete
