---
loop: 61
branch: dev
---

# Pack side `held_of` (loop 61)

Source: `_docs/loops/loop60/handoff61.md` candidate "`pack_children` still decides When / FlagBit inline (the `held_of` idea on the pack side; flash cost unknown, margin 160 B)". The hopper was empty; the owner picked it in chat on 2026-10-23.

## Problem

On the unpack side one function, `held_of` (`cpp/src/core/unpack.cpp`), decides what a `when` or a flag bit asks of its walker (Skip, Inline, Scope, Bit), and `unpack_children` and `unpack_one` both ask it. On the pack side the same decision is written twice: `pack_children` tests `when_matches` for a `when` child and enters its children in its own loop, while `pack_one` repeats `when_matches` for `Kind::When` and tests `present(i + 1)` for `Kind::FlagBit`. A flag bit child of a group or `when` goes through `pack_one`, so a chain of flag bits costs a `pack_one` frame per level that a `when` chain does not.

The loop builds the pack-side counterpart, measuring first: whether one decision point shared by `pack_children` and `pack_one` costs or saves flash and stack on the Cortex-M4F image, and keeps it only when the figures allow.

## Code sections / UI locations for this loop

No UI. The owner named: "`pack_children` decides When/FlagBit inline" (the choice text of the loop 61 pick).

| Work | Place |
|------|-------|
| The decision and its two callers | `cpp/src/core/pack.cpp` (`pack_children`, `pack_one` cases `When`, `FlagBit`) |
| Model to follow (read only) | `cpp/src/core/unpack.cpp` (`held_of`, `unpack_children`) |
| Budgets | `cpp/embedded/lib.sh` (`flash_pin=8032`, `stack_budget=512`), `docs` margins in `_docs/AGENT_GOTCHAS.md` |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Flash margin is 160 B (pin 8,032 of 8,192); any growth of `cpp/src/core` must be paid by a saving first | `AGENT_GOTCHAS.md` (loop 57); raising the pin needs a line there | open | High |
| Stack margin is 8 B; a deeper pack walk fails the arm stage | `AGENT_GOTCHAS.md` (loop 42/57) | open | High |
| The result may be "no gain": then the source stays as it is and the figures are recorded | owner pick is "measure first" | open | Low |
| `pack.cpp` is also built by GCC 16 with `-Werror` and by avr-gcc 7.3 (no C++ library) | standard names only from `packbin/platform.hpp` | open | Medium |
| Other candidates (`Field` layout, flag-byte chain in `times`, session stack, owner items) | not this loop | accepted-risk | Low |
