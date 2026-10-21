# Batch Report

**Batch**: 2 (loop 53)
**Tasks**: AZ-2757_rust_core_hostile_and_docs
**Date**: 2026-10-21

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2757_rust_core_hostile_and_docs | Done | core: `present.rs` (count fix), `text/` split into `encode.rs`, `parse.rs`, `raw.rs` + memo; tests: 5 new files + `nostd_support/hostile.rs`; probe, run-suite, 4 documents | 6 hostile + 3 hostile-pack + 7 fixture-differential + 5 raw-repeat + 1 docs, all pass | 2 core divergences found and fixed (below) |

## Code Review Verdict: deferred

One total `/code-review` at the end of the loop (owner rule 2026-10-06).

## Test Suite

- AC-1: `nostd_hostile_tests` (15 unpack + 2 limit + 14 construct cases, the fuzz corpus under every case scheme, 40 mutations per corpus input), `nostd_hostile_pack_tests` (17 pack cases run with the C++ answers, the 3 `novalue` cases the C++ runner skips run too, 18 skipped with the C++ reasons)
- AC-2: `nostd_fixture_differential_tests`: golden, 346 + 42 text vector rows, 35 ECC `enc` rows, every hostile case and corpus input and mutations of them, construct cases refused by both walkers
- AC-3: `cargo publish --dry-run` from a copy with the root `README.md` (as `publish-inside.sh`): pass, 145 files; `cargo build --no-default-features`: pass
- AC-4: `nostd_docs_tests` (README, module layout, component description name `nostd`, the features and `embedded-arm`)
- Embedded stage (QEMU Cortex-M4F): PASS, no heap or panic symbol. Base 14,652 B / 456 B (was 14,532 B: +120 B from the `pack_clear` split), `text` 26,592 B / 2,760 B (nested probe), `ecc` 17,932 B / 760 B, `session` 18,196 B / 1,776 B
- CI-parity: PASS (the `run-suite.sh rust` command list run by hand: default, no-default flat, text, ecc, the `text,ecc` hostile set, session x2, `text,ecc,session` all targets; clippy with the `nostd` deny lints; `run-suite.test.sh`; `checks.test.sh`; embedded stage)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `pack_count_one_clear_when` packed `0100025a00` on the core: a `times` count the row holds above 0 while its source is not written (its `when` is clear) counted as an absent member | AC-1 | `present` treats such a count as the `times` (and, #3, a `sized`, `bits` or `packed` without a value) being on, so pack refuses it, naming the `times` (BadValue, as the C++ runner and the case file require) | clear (the case file) |
| 2 | 200 rounds of a 65,535-character raw text: core pack 5.96 s (release, host load 46) against `std` 0.010 s; the TW-5 bound is 1 s nominal | risk "raw memo" | ported the C++ scratch-word memo (AZ-2742): 14 ms, packets unchanged; a pack clears the memo first; a compact result clears it | clear (measured) |
| 3 | The three `pack_novalue_count_clear_when_*` cases (C++ open row U24) packed the clear bit on the core, where `std` and the case file refuse | AC-1, AC-2 | the same fix as #1 for `sized`, `bits` and `packed`: the member counts as present, pack refuses it naming the member; the three run on the core (the C++ package keeps U24 open) | clear (the case file) |
| 4 | `encode.rs` was 518 lines (over the 500 cap) before this loop and 565 with the memo | quality threshold | split by responsibility: `parse.rs` (cost table, solver), `raw.rs` (memo), `encode.rs` (bit writer, field) | clear |
| 5 | The `text` stack figure with the nested probe is 2,760 B (the probe frame holds two copies of the rows); the library part is smaller | AC (nested probe) | reported; no limit until the owner sets one | unclear (owner input) |

## Commit

`[AZ-2757] Rust nostd core: hostile corpus, differential proof, raw memo, docs`. Body: one line + `Loop: 53`.

## Next Batch: All tasks complete
