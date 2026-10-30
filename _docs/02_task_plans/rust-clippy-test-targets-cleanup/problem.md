---
loop: 87
branch: dev
---

# Rust clippy on test targets (loop 87)

Source: `_docs/loops/loop86/handoff87.md` (candidates), probed on HEAD d088ba2 on 2026-10-30. The owner chose "Probe candidates", then "Spec test-target clippy". No UI.

## Problem

`cargo clippy --lib --tests --features text,ecc,frame` in `rust/` reports 6 distinct warnings on HEAD (toolchain 1.97.1), repeated per test target that includes the shared file:

| Lint | Where |
|------|-------|
| `type_complexity` | `src/text_vectors_tests.rs:243` |
| `manual_is_multiple_of` | `tests/nostd_bits_when_tests.rs:215`, `tests/nostd_rounds_tests.rs:141`, `tests/nostd_text_differential_tests.rs:151`, `tests/nostd_support/random.rs:19` |
| `err_expect` | `tests/nostd_hostile_tests.rs:157` |

Loop 86 brought the lib to 0 warnings and excluded test targets. No CI job runs clippy; this loop does not add one.

Probed and dropped (reasons stand): the AVR `chacha20_xor` runtime check (the code already counts down by remaining bytes, so a 16-bit `size_t` cannot wrap; running it needs an AVR emulator that the host and the `packbin-embedded` image lack), the Go window floor (conditional, no stalled ask seen), ring driver for `nostd`, 128 KiB image, cycle timing (hardware or owner, no change since loop 74).

## Change location

No UI. Verbal: the Rust test code in `rust/src/text_vectors_tests.rs` and `rust/tests/`, the files in the table above. No library code changes.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `is_multiple_of` needs Rust 1.89; no MSRV is pinned, CI uses 1.97+ (`RING_RUST`) and 1.98 (embedded) | none stated | open | Low |
| A test rewrite must keep the property it checks (`random.rs` coin flip stays the same draw) | AC-2 (test pass counts unchanged) | open | Low |
