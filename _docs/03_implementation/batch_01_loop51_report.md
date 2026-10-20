# Batch Report

**Batch**: 1 (loop 51)
**Tasks**: AZ-2752_rust_core_bits_and_when
**Date**: 2026-10-20

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2752_rust_core_bits_and_when | Done | 16 files: `rust/src/nostd/` (5 new: `check.rs`, `table.rs`, `present.rs`, `pack.rs`, `unpack.rs`; `scheme.rs`, `row.rs`, `io.rs`, `walk.rs`, `mod.rs` changed), `rust/tests/nostd_bits_when_tests.rs` and `nostd_support/tree.rs` (new), `nostd_support/mod.rs`, `nostd_differential_tests.rs`, `rust/embedded/limits.txt` | 11 new pass; Rust suite 818 pass / 0 fail | flash limit (decided, below) |

## Design

- The scheme stays a plain `&[Field]`: entries in preorder with a `span` (the C++ table shape). `Field` gains `span`, `source`, `eq`, `width`, `bias` (24 B on Cortex-M4F, was 6 B). Builders take the number of member entries (`flags(id, entries)`, `when(id, source, value, entries)`, `flag_bit(number, entries)`, `u2(id, n)`).
- Order ids follow the C++ rule: `flags`, `when` and `u2` take the id of their first member, a flag byte and a flag bit take none (`NO_ID`). (The std Rust API gives a flag byte an id; the hostile README already names this difference.)
- The C++ core stores the references (`ref`, bit positions, late links) in its table when the scheme is built. Here they are found where they are used (`table.rs`): a scan of the table per lookup. A scheme is a small, trusted constant, so the cost is CPU time, not memory.
- `Row` gains methods with default bodies: `flag`/`set_flag` (`boolean`), `clear` (called for every member before an unpack, so a skipped member reads as absent), `slots`/`set_count` (caller storage for `sized`, `bits`, `packed`; shorter storage is `TooMany` with nothing written). Pack reads those values from `bytes`.
- `pack` and `unpack` take `&dyn Row` / `&mut dyn Row` (were generic): the image held one copy of the walk per row type.

## Code Review Verdict: not run per batch

Owner rule (2026-10-06): one total review per loop. `cargo clippy` with the `nostd` deny list (`unwrap_used`, `expect_used`, `panic`, `indexing_slicing`, `arithmetic_side_effects`) is clean.

## Test Suite

- `bash .github/workflows/run-suite.sh rust` (the CI suite step): 818 passed, 0 failed, 48 s.
- `cargo test --no-default-features --test nostd_flat_tests`: 12 passed.
- New `nostd_bits_when_tests` (11): random rows over 13 layouts, 3,000 rows each (same bytes, same values read back, same accept/refuse); every cut and a trailing copy (`ShortPacket` / `TrailingBytes`); 8,000 random packets per layout read alike; the 32-row presence matrix; stale members cleared; 20 schemes std refuses and 19 tables only the core can write, all `SchemeInvalid` with no byte written; hostile `pack_split_false_condition_silent` (`0100025a00`), `pack_split_when_source_after_byte` and `count_behind_clear_flag`; storage limits; value ranges.
- Embedded stage (`rust/embedded/run.sh host`): golden decoded, no heap, no panic path, mutants caught; flash 11,028 B, stack 396 B (14-field route probe).
- CI-parity: PASS (the Rust suite step above; the ring and the publish gate run in step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Flash of the base image went from 2,652 B to 12,108 B (11,028 B after the `dyn Row` change) against the 8,192 B limit | AZ-2751 AC-2, AZ-2749 limits | Owner chose 2026-10-20 "raise to 16 KB": `limits.txt` base is 16,384 B flash, 512 B stack | clear (owner) |
| 2 | AC-2 "an empty `when` body": neither the std walker nor the C++ core refuses an empty `when`; both refuse a `repeat`/`times` body that holds only empty `when`s (hostile `construct_empty_when_*`) | AZ-2752 AC-2 | An empty `when` is accepted as in std; the empty round body rule comes with rounds in AZ-2753 | clear (std behavior and the hostile README) |
| 3 | A `when` whose source sits inside a `when` that does not hold: std treats the source as not written (no match); the C++ core reads the row and writes the body. C++ packs `21 00 05` for `u8 mode=0; when(mode==1){u16 a; u8 k=2}; when(k==2){u8 b=5}` and its own unpack refuses it (`TrailingBytes`, checked in `gcc:16` today) | none (cross-package) | The new core follows std (`source_value` checks every `when` around the source, as C++ does for counts only). The C++ fix and a hostile case belong to their own task (in the loop record leftovers) | clear for Rust; the C++ fix is out of this loop |
| 4 | A row field the scheme reads with another number kind | AZ-2752 AC-4 | Present (its bit is set), then pack refuses it with `BadValue`; a `when` or count does not match it | clear (same as a flat field) |
| 5 | Kinds the std API accepts as `when` or count sources and the core does not: a flag byte and a `flags` byte (std gives them a name) | AZ-2752 AC-2 | Not sources in the core (C++ rule: they take no id) | clear (hostile README: flag byte "no order id elsewhere") |
| 6 | `bool` in the core is `boolean(id)`, an entry of its own that takes an id; std writes it as an empty `group` | AZ-2752 | Same wire and order; the empty `group` comes with groups in AZ-2753 (refused or mapped there) | clear |

## Commit

`[AZ-2752] Rust nostd core: flags, bits, u2, packed, sized and when`. Body: one line + `Loop: 51`.

## Next Batch: AZ-2753_rust_core_lists_and_dicts
