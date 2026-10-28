---
loop: 79
branch: dev
---

# Ring driver number ranges and Rust test-build fixes

## What

Two cleanups the loop 78 handoff listed, probed on HEAD (`cb6759b`) in this loop before writing this file.

**The frame ring drivers narrow numbers silently.** The 8 frame drivers of the cross-language ring (`.github/workflows/drivers/`) read decimal numbers from each line and pass them to their package. Three drivers cast a number to a smaller type without a check, so a value the reference codec (`scripts/frame/framefmt.py`) refuses becomes a value the package accepts, and the ring then reports the *package* as wrong. A probe ring (`RING_FRAME_CASES` with extra rows, not committed) gave, for rows the reference answers with `BadValue`:

| Value in a row | Silent wrap (sealed or opened instead of `BadValue`) | Ends loudly (`frame line N`, exit non-zero) | Package answers `BadValue` |
|---|---|---|---|
| direction 257, 258 (seal and open) | C# `(byte)d`, C++ `static_cast<std::uint8_t>`, Go `uint8(d)` | none | TypeScript, Python, Rust, Java, Swift |
| tag length 260 (seal and open) | C++ | Rust (parses `u8`) | C#, TypeScript, Python, Java, Go, Swift |
| kind 256, 260 | C++ | Rust, Swift (parse `u8`) | C#, TypeScript, Python, Java, Go |
| epoch 4,294,967,297 (seal and MAC) | Go `uint32(epoch)` | C#, Java (Int32), C++ (`stoi`), Rust, Swift | TypeScript, Python |
| MAC `n` 260 | none | none | all 8 |
| direction -255 | none | TypeScript, Rust, C++, Go, Swift ("bad number") | Python (`int()` takes a sign) |

A huge `out_len` (the caller's output buffer) is allocated as given: 2,147,483,647 makes C# and Java run out of memory; 1,099,511,627,776 makes the OS kill the Python and Swift drivers (`Killed: 9`) on this Mac, C#, Java and C++ refuse to parse it, and Rust, TypeScript and Go succeed because the page allocation is lazy. The reference accepts any `out_len`.

**The ring checker hides mismatches.** `scripts/frame/ring_frame.py` prints at most 5 mismatch lines for a pair and 5 for a reader's refusals (`wrong[:5]`, `refused[:5]`) and says nothing about the rest: in the probe, C++ had 7 refusal mismatches and showed 5 (the two kind rows were hidden).

**The Rust test builds warn and one class of defect is not built.** `cargo +1.98 test --no-default-features --features frame --no-run` (and `text,ecc,frame`) prints 3 warnings for 4 items: `test_previous_is_zero` and `test_material` (`rust/src/nostd/frame/mod.rs:363`), `hmac_sha256_of` (`rust/src/session_core/hkdf.rs:76`) and `block_of` (`rust/src/session_core/pad.rs:89`). They are `#[cfg(test)]`, but their only callers (`frame_hostile_tests`, `frame_core_tests`, `crypto_vectors_tests`) are built under `cfg(all(test, feature = "std", ...))` (`rust/src/lib.rs:57-64`). The all-features build warns once per nostd test crate (9 crates) about `pub use super::from_hex;` in `rust/tests/nostd_support/hostile.rs:137`, used by 3 of them, and the default build about `take` (`rust/src/session_core/counters.rs:18`, called only by the two frame test modules; found by the AZ-3357 worker, the intake probe had not built the default set). `run-suite.sh` already runs `cargo test --all-features` (AZ-3338 AC-6, line 313), so that handoff item is done; what is missing is a build of *every* test target in the no-std feature sets: the suite names its no-std targets one by one (`--test <name>`), which hid a missing `#![cfg(feature = "std")]` in 22 test files in loop 76 (LESSONS).

## Why

A ring result must mean what it says: a driver that turns `dir=257` into `Up` makes the ring blame a correct package, and one that allocates a terabyte can take down the host. One range rule for every number in every driver makes the 8 drivers behave alike, and the loader keeps the ring rows inside it. The Rust check stops the next missing feature gate in CI instead of in a later loop.

## Who

The maintainers of the 8 packages, through the CI `ring` job, the CI `suites` job (Rust) and `scripts/loop-tests.sh`.

## Behavior (owner, 2026-10-28: "Accept all recommended")

1. **One range rule.** Every number on a driver line is decimal digits only (no sign, no space, no `_`, no `+`) and lies in its field's range: direction, tag length, kind and MAC `n` 0 to 255; epoch 0 to 4,294,967,295; `out_len` and `clear_len` 0 to 65,535. A number outside its range, or with any other character, ends the driver with a non-zero exit and a message naming the line, as a bad hex digit does since loop 78. All 8 drivers apply it to every number field of `seal`, `open`, `mac` and `verify` lines. A number inside the range goes to the package unchanged (a direction of 255 is the package's `BadValue` to give).
2. **The loader keeps the rows inside the rule.** `ring_frame.py` stops with exit 1 and names the row when a row of `ring-cases.txt` holds a number outside its range. `fixtures/frame/README.md` states the ranges.
3. **Rows at the top of each range.** `ring-cases.txt` gains rows at the top of each range, so the ring shows that every driver hands those values on unchanged: direction 255, tag length 255, kind 255, epoch 4,294,967,295 (refused by name as `BadValue`), MAC `n` 255 (`BadValue`), and a seal row with `out_len` 65,535 (the sealed body).
4. **"And N more".** When a pair or a reader has more than 5 mismatches, the checker prints the first 5 and a line `... and N more`.
5. **Rust cfg fixes.** The 4 test helpers carry the cfg of their callers; the unused re-export goes (the 3 users import `from_hex` from `nostd_support`). No test is removed.
6. **Every no-std test target is built.** `run-suite.sh` (the Rust branch, run by CI and by step 11) builds all test targets with `--no-run` for the 7 sets none, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame` (all with `--no-default-features`), plus the default and all-features sets, and fails the suite when a build fails or prints a `warning:` line.

Decided earlier and kept: Rust prints `BadValue` itself for directions 0 and 4 (U1 of loop 78); multi-part MAC messages and key and `msg_id` length refusals stay out.

## Out of scope

Multi-part MAC rows (a new driver line format), the AVR runtime check of `chacha20_xor`, the public-key pairing step, the owner-held items of the handoff (tags, F44, CS-D5, U24, the M4F row, release notes, the meshbell rename, vcpkg on Windows), the timing-selftest flake (L76-1), Rust clippy.

## Code sections / UI locations for this loop

The owner's pick named these places (intake, 2026-10-28):

- `.github/workflows/drivers/` (the 8 frame drivers: `handoff_frame.py`, `handoff-frame.ts`, `HandoffFrame.java`, `csharp/HandoffFrame.cs`, `handoff-go/frame.go`, `handoff-rust/src/frame.rs`, `handoff-swift/Sources/handoff-swift/Frame.swift`, the frame section of `handoff.cpp`), with `fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`, `scripts/frame/ring_frame.py`, `.github/workflows/ring-frame-drivers.test.sh` and `.github/workflows/ring-frame.test.sh`
- `rust/tests` and the `cfg(test)` helpers behind the warnings (`rust/src/nostd/frame/mod.rs`, `rust/src/session_core/hkdf.rs`, `rust/src/session_core/pad.rs`, `rust/tests/nostd_support/`)
- `.github/workflows/test.yml`, `.github/workflows/run-suite.sh`, `.github/workflows/run-suite.test.sh` and `scripts/loop-tests.sh`

## Flagged concerns

| concern | policy / owner | status | severity |
|---|---|---|---|
| Eight drivers change at once; a driver edit not run on its toolchain breaks CI (loop 77: six defects in the first push) | run the real ring, the driver script and every `test.yml` ring step before the first push (LESSONS, loop 77); Swift driver checked in `swift:6.3.3`, C++ in `gcc:16` | open | Medium |
| The new driver checks pass on the first run and prove nothing alone | put the HEAD drivers back in a scratch copy and see the new cases fail (LESSONS, loop 78) | open | Low |
| The range rule changes how Python, TypeScript and Java answer a direction above 255 (package `BadValue` today, loud exit after) | owner accepted the uniform rule on 2026-10-28; no ring row has such a value | accepted-risk | Low |
| The CI `suites` job of Rust gets 7 more builds | measured on this Mac: 1 to 3 s each with the crate built; AC-12 bounds the step 11 stage | open | Low |
