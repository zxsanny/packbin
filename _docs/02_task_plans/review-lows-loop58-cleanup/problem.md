---
loop: 59
branch: dev
---

# Review Lows of loop 58: two test cleanups (loop 59)

Source: `_docs/loops/loop58/handoff59.md` ("Review Lows of loop 58") and `record58.md` leftovers. The hopper was empty; the owner picked "Review Lows of loop 58" in chat on 2026-10-22. Test-only loop: no change under `cpp/src`, `cpp/include`, or any library source, so the Cortex-M4F flash (8,032 B, pin 8032) and stack margins stay as they are.

## Problem

1. **Rust corpus count rule is loose** (`listed_inputs`, `rust/tests/nostd_hostile_tests.rs`). It counts any line of exactly three fields whose last is hex, so a three-field `#` comment with a hex-looking last token is counted and the equality with the loader fails for the wrong reason. Its `!f[2].is_empty()` is dead (`split_whitespace` yields no empty field). The README (`fixtures/hostile/fuzz/README.md`) defines an input as `name kind hex` with `name` in `[a-z0-9_]+` and hex the whole packet (never empty), so that is the rule to count by. A `-` placeholder is not part of the format, so nothing is added for it.
2. **C++ `put_key` is unchecked** (`cpp/tests/core/dict_order_host_tests.cpp`). It copies `n` bytes into a `Text<4>`; a later pair with `n > 4` would overflow the test's own key.
3. **C++ `packs_in_order` hides the refusal check behind one message.** Every refused pair reports "a refused key order is BadValue", so a failure does not say which pair. The helper returns only a bool.

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-22 (the loop 58 handoff candidate names these places). No UI. Test files only.

| Work | Place |
|------|-------|
| Rust count rule | `rust/tests/nostd_hostile_tests.rs` (`listed_inputs`), `fixtures/hostile/fuzz/corpus.txt` and `README.md` (read only) |
| C++ `put_key`, `packs_in_order` | `cpp/tests/core/dict_order_host_tests.cpp` |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A C++ test edit must not change the library source or the flash/stack figures | no edit under `cpp/src` or `cpp/include`; the arm figures are read from the pin, not re-measured | open | Low |
| The new count rule must not be a second copy of the loader's `#` filter | it counts by the README name rule, shown with a broken copy | open | Low |
| Candidates left for later: `pack_children` `held_of`, `Field` layout, flag-byte chain inside a `times` round, session stack items of loop 53, owner items | not this loop | accepted-risk | Low |
