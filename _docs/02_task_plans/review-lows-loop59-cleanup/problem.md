---
loop: 60
branch: dev
---

# Review Lows of loop 59: two test cleanups (loop 60)

Source: `_docs/loops/loop59/handoff60.md` ("Review Lows of loop 59") and `record59.md` leftovers (review findings 1 to 4, all Low). The hopper was empty; the owner picked "Review Lows of loop 59 + retro" in chat on 2026-10-22. Test-only loop: no change under `cpp/src`, `cpp/include`, or any library source, so the Cortex-M4F flash (8,032 B, pin 8032) and stack margins stay as they are. The retrospective (last: loop 55) runs after the tests.

## Problem

1. **C++ pair failures do not show the `Error` returned** (`cpp/tests/core/dict_order_host_tests.cpp`, `pack_orders_keys_as_unsigned_bytes`). A failing pair prints its fixed message only; the reader cannot tell `Ok` from `BadValue` from any other `Error` without a debugger.
2. **C++ `put_key` leaves an empty key when it refuses an oversize key**, and `pack_error` still packs the pair, so the pair's result is the result of a different input and can match its expectation by chance.
3. **Rust count rule skips the kind field and the hex case** (`listed_inputs`, `rust/tests/nostd_hostile_tests.rs`). The README defines `kind` as a scheme id (every kind in the corpus is `[a-z0-9_]+`) and `hex` as lowercase, whole packet; the rule checks neither.
4. **Rust count rule allocates a `Vec` per corpus line** for the field split.

## Code sections / UI locations for this loop

No UI. Test files only.

| Work | Place |
|------|-------|
| C++ `put_key`, `pack_error`, the 7 pairs | `cpp/tests/core/dict_order_host_tests.cpp` |
| Rust count rule | `rust/tests/nostd_hostile_tests.rs` (`listed_inputs`), `fixtures/hostile/fuzz/corpus.txt` and `README.md` (read only) |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A C++ test edit must not change the library source or the flash/stack figures | no edit under `cpp/src` or `cpp/include`; the arm figures are read from the pin, not re-measured | open | Low |
| The firmware runner compares `expect(` call sites per file | `dict_order_host_tests.cpp` is a host test only; a helper that wraps `expect` keeps one call site per assertion | open | Low |
| Candidates left for later: `pack_children` `held_of`, `Field` layout, flag-byte chain inside a `times` round, session stack items of loop 53, owner items | not this loop | accepted-risk | Low |
