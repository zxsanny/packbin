# Blackbox tests 21 — `when` chain stack, bool source behind a clear `when`, repeated-text headroom (loop 55)

Loop 55 (AZ-3132, AZ-3133, AZ-3134, AZ-3141). Three cases join `fixtures/hostile/cases.txt` (75 cases now) and run in all eight packages.

## FT-X-132: `pack_when_of_skipped_bool_source`, `..._held_bool_source`, `..._held_bool_source_clear`

| Item | Value |
|------|-------|
| Scheme | `u8 mode; when(mode == 1) { flags { bool on }; u8 a }; when(on == true) { u8 b }` |
| Rows | mode 0 / on true; mode 1 / on true; mode 1 / on false (a = 7, b = 5) |
| Expected | `bytes` `0100`, `0101010705`, `01010007` in all eight packages (Python packets of 2026-10-21) |
| Run by | all eight (Rust std and no-heap core) |
| Not run by | none |

Empty-group source (C++ and Rust only; the other six refuse it): Rust `when_bool_source_tests.rs` (`0100`, `0101010705`, `01010007`), C++ `when_group_source_host_tests.cpp` (`0100`, `0101070105`, `01010700`: `u8 a` before the group, AZ-2334).

## FT-X-133: `when` chains on the Cortex-M4F image

All-kinds image schemes `ChainRow` (0x5b: `u8 m; when(m==1){u8 k1; when(k1==1){u8 k2; when(k2==1){u8 k3; when(k3==1){u8 b}}}}`) and `FlagChainRow` (0x5c: the same with a flag byte and bit in each level), 4 rows each, packets equal to Python's; host test `when_chain_host_tests.cpp`; stage figures: plain chain 348 B pack / 292 B unpack, flag chain 384 B / 500 B, deepest 504 of 512 B, flash 8,120 of 8,192 B.

## FT-X-134: 65,535 characters in 200 rounds, seven packages

Pack / unpack seconds on this Mac: Python 0.10 / 0.003, TypeScript 0.04 to 0.07 / 0.01, Java 0.02 / 0.005, C# 0.02 to 0.04 / 0.005 to 0.03 (0.11 / 0.12 first typed call under load), Rust 0.012 / 0.003 (release), Go 0.02 / 0.002, Swift 0.0045 / 0.0063 (release), C++ 0.009 / 0.009. All below half the 1 s bound. New tests: `go/text_repeat_speed_test.go`, `TextRepeatSpeedTests.swift` (extension of `TextSpeedTests`).

## Stage 11 at the loop 55 close

`scripts/loop-tests.sh`: 14 stages passed, 0 skipped as unchanged, 0 failed, 1049 s. Embedded: flash 8,120 B (margin 72 B), stack 504 B (margin 8 B).
