# Batch Report

**Batch**: 2 (loop 51)
**Tasks**: AZ-2753_rust_core_lists_and_dicts (without dictionaries, moved to AZ-2754)
**Date**: 2026-10-20

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2753_rust_core_lists_and_dicts | Done (repeat, group, times, lists; dicts moved) | `rust/src/nostd/` (`scheme.rs`, `row.rs`, `check.rs`, `table.rs`, `present.rs`, `pack.rs`, `unpack.rs`, `io.rs`, `walk.rs`, `mod.rs`), `rust/tests/nostd_rounds_tests.rs` (new), `nostd_support/random.rs` (new, the row generator moved out of the AZ-2752 test), `nostd_support/tree.rs`, `nostd_support/mod.rs`, `nostd_bits_when_tests.rs`, specs AZ-2753 and AZ-2754 | 11 new pass; Rust suite 829 pass / 0 fail | dict move, round limit (below) |

## Design

- New kinds `group`, `repeat`, `times`, `list` (builders take the member entry count, as in batch 1). `repeat`, `times` and `list` are containers: their members read into items of their own, and they open a scope (a `when`, count or flag bit inside sees only the round).
- `Row` gains `count`, `item`, `item_mut` (defaults return `None`); `set_count` also takes the items filled. An item is a `&dyn Row`, so a round of a struct is a struct that implements `Row`; the worked example is a route of up to eight points in plain arrays (`nostd_rounds_tests.rs`).
- A `list` takes the next order id (the row finds its items by it); the other packages give a list a name only, so ids after a list are one higher in the core. A wrong id fails `validate` (no silent shift).
- `Scheme` gains `max_rounds` and `max_slots` (std defaults 65,535 and 1,048,576; `with_limits`). A round past either is `TooMany` naming the container and the limit, on pack and unpack. Storage smaller than the count is `TooMany` with the count; no item past the storage is written.
- Checks: no `repeat` in a round, no `times` in a `times` round, a round body holds a member (looking through `when`, groups, flag bits), a list element is a number, `bytes`, a list or a `u2` of one member, a group has members (a presence bit is a `boolean`).

## Code Review Verdict: not run per batch

Owner rule: one total review per loop. Clippy with the `nostd` deny list is clean.

## Test Suite

- `bash .github/workflows/run-suite.sh rust`: 829 passed, 0 failed.
- New `nostd_rounds_tests` (11): random rows over 14 layouts, 3,000 each (same bytes, same rounds and values read back); every cut and a trailing copy read alike (a cut of a `repeat` at a round boundary is a valid packet); 6,000 random packets per layout read alike; rounds at and over the limit; slots over the limit on pack and unpack; storage limits; hostile counts (2^32 - 1 rounds, 65,535 items) end at once with `ShortPacket`; a zero-progress `repeat` round; 11 schemes std refuses and 6 tables only the core can write; the route worked example.
- Embedded stage: PASS, flash 13,844 B of 16,384, stack 472 B of 512, no heap, no panic path, mutants caught.
- CI-parity: PASS (the Rust suite step).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Every dict key is a string and key order is compared on decoded text (C++ `compare_payloads` runs the decoder), so dicts cannot ship before the text slice | AZ-2753 scope (dicts), AC-3 | Moved to AZ-2754 (scope line and AC-5 added there, about 2 points; re-estimate at its intake) | clear (the spec's own exclusion of dict-key strings makes AC-3 unbuildable here) |
| 2 | The std round limit counts all rounds one field starts in a call (a `times` inside a `repeat` adds up over the repeat rounds); a heap-free walk keeps no counter per field | AZ-2753 AC-2 | The core limits rounds per container where it stands (each time it is read), plus the shared slot budget and the storage; a `times` inside a `repeat` that passes 65,535 rounds in total but not in one place is read by the core and refused by std | clear (the slot budget and storage bound the work; documented on `Scheme::max_rounds`) |
| 3 | A `list` has no order id in the other packages, but the row needs a key for its items | AZ-2753 | The list takes the next order id; `validate` refuses a scheme numbered the other way | clear |
| 4 | An empty `group` is a bool in std | AZ-2753 | Refused in the core (`boolean` is the presence bit) | clear |
| 5 | Stack of the flat probe went from 88 B (loop 50) to 472 B of 512 with the nested walk; keeping helpers out of line did not change it (tried, reverted) | AZ-2751 AC-2 | Within the limit; the margin is 40 B, and the probe is flat only: a nested probe and a stack look belong to AZ-2757 (handoff) | clear |
| 6 | A list element that reads nothing (`bytes(0)`) | AZ-2753 AC-4 | `BadValue`, as std refuses it (the differential test agrees) | clear |

## Commit

`[AZ-2753] Rust nostd core: repeat, group, times and lists`. Body: one line + `Loop: 51`.

## Next Batch: All tasks of the loop complete (AZ-2754 to AZ-2757 stay in `todo/`)
