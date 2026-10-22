---
loop: 58
branch: dev
---

# Review Lows of loop 57: three test guards (loop 58)

Source: `_docs/loops/loop57/handoff58.md` ("Review Lows of loop 57") and `record57.md` leftovers. The owner chose "Accept all recommended" on 2026-10-22. The hopper was empty; the interview is that choice plus the evidence below. Test-only loop: no change under `cpp/src`, `cpp/include`, or any package's library source, so the Cortex-M4F flash (8,032 B, pin 8032) and stack margins stay as they are.

## Problem

1. **Rust nostd corpus count guards only the literal.** `ac1_the_fuzz_corpus_reads_without_a_panic_and_its_hostile_inputs_keep_their_outcome` (`rust/tests/nostd_hostile_tests.rs`) counts `corpus.txt` lines with the same filter (`!trim().is_empty() && !starts_with('#')`) that `rust/tests/nostd_support/hostile.rs` uses to load them, so a wrong filter is wrong in both and the equality still holds.
2. **Go refusal check prints two lists.** `TestHostileEveryRefusalPinsOneRule` (`go/hostile_pack_test.go`) fails with `pack_error cases [...], pinned rules [...]`; the reader has to diff two map-ordered lists by eye. `idDifference` already names each missing, unused and duplicate id.
3. **No helper-level test of the dict key order with a high byte.** `keys_ascending` (`cpp/src/core/pack.cpp`) was rewritten in AZ-3151 as an inline byte loop; no test pins the compare on a byte at or above 0x80 against one below it (`0x80` vs `0x7f`) nor on a prefix pair (`"a"` vs `"ab"`), the two places a signed `char` or a length-first compare would go wrong.

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-22 (all recommended). No UI. Test files only.

| Work | Place |
|------|-------|
| Rust nostd count check | `rust/tests/nostd_hostile_tests.rs` (the `listed` count), `rust/tests/nostd_support/hostile.rs` (the loader filter), `fixtures/hostile/corpus.txt` (read only) |
| Go refusal check | `go/hostile_pack_test.go` (`TestHostileEveryRefusalPinsOneRule`), `go/hostile_loader_test.go` (`idDifference`, read only) |
| `keys_ascending` test | `cpp/tests/core/dict_order_host_tests.cpp` (and `cpp/tests/core/main.cpp` only if a registration is needed) |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A new C++ test must not change the library source or the flash/stack figures | the arm stage is run unchanged; no edit under `cpp/src` or `cpp/include` | open | Low |
| An independent count must not be a second copy of the same filter | the check uses a different rule than the loader and is shown with a broken copy | open | Low |
| Candidates left for later: `pack_children` `held_of`, `Field` layout (`item`, `count`), flag-byte chain inside a `times` round, session stack items of loop 53, owner items (size limits, CS-D5, tags, F44, AZ-2750, U24) | not this loop | accepted-risk | Low |
