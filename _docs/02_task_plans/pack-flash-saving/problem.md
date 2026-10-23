---
loop: 63
branch: dev
---

# Pack.cpp flash saving, then the pack-side `held_of` (loop 63)

Source: `_docs/loops/loop62/handoff63.md` (owner question "whether to spend the new 384 B flash margin on the pack-side `held_of`") and the loop 61 result (`held_of` costs +44 to +72 B of Cortex-M4F flash and saves 0 to 8 B of pack stack; `AGENT_GOTCHAS.md`: "do not retry it without a flash saving of at least 72 B found first in `pack.cpp`"). The hopper was empty; the owner picked the work in chat on 2026-10-23: "look for a flash saving of at least 72 B in pack.cpp first, then decide on the pack-side held_of".

## Problem

The Cortex-M4F image is at 7,808 B of an 8,192 B budget (pin 7,808 B, margin 384 B) and the stack at 496 of 512 B. Every edit to `cpp/src/core` must be paid by a saving first. The pack-side `held_of` (one function deciding skip / enter inline / enter a flag bit's child for a `when` or a flag bit, asked by `pack_children` and `pack_one`) removes a duplicated decision but cost up to 72 B of flash in loop 61, so it was dropped.

This loop has two parts, in order:

1. Find a flash saving in `cpp/src/core/pack.cpp` of at least 72 B, with the wire output and the stack unchanged or lower.
2. Only when part 1 reaches 72 B: rebuild the loop 61 `held_of` shape on top of it and keep it only when it pays for itself.

## Code sections / UI locations for this loop

No UI. The owner named "pack.cpp" ("a flash saving of at least 72 B in pack.cpp") and "the pack-side held_of".

| Work | Place |
|------|-------|
| The saving, and the `held_of` decision with its two callers | `cpp/src/core/pack.cpp` |
| Loop 61 shape to rebuild (read only) | `_docs/loops/loop61/pack_held_of_a.patch`, `_docs/02_tasks/done/AZ-PENDING_cpp_pack_held_of_measure.md` |
| Model on the unpack side (read only) | `cpp/src/core/unpack.cpp` (`held_of`) |
| Budgets and probe | `cpp/embedded/lib.sh` (`flash_pin=7808`, `stack_budget=512`), `docker compose -f docker-compose.test.yml run --rm cpp-embedded`, margins in `_docs/AGENT_GOTCHAS.md` |

Excluded: unpack, `Field` layout, `values.hpp`, the other seven packages.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Flash margin 384 B (pin 7,808 B), stack margin 16 B; a deeper pack walk fails the arm stage | `AGENT_GOTCHAS.md` (loops 62, 57) | open | High |
| No 72 B saving may exist in `pack.cpp`; then no `held_of` build, no pin raise, the loop closes with the report | owner default (Phase 1, 2026-10-23) | open | Low |
| A saving below 72 B is kept when it is a pure reduction (flash lower, stack not higher, wire output equal); the pin goes down to the new figure. Assumption from the owner's "keep the saving regardless" | owner default (Phase 1, 2026-10-23) | accepted-risk | Low |
| `pack.cpp` is also built by GCC 16 with `-Werror` and by avr-gcc 7.3 (standard names only from `packbin/platform.hpp`) | `AGENT_GOTCHAS.md` (loops 18, 44) | open | Medium |
| Other candidates (`item` pointer removal, flag-byte chain in `times`, session stack, owner items) | not this loop | accepted-risk | Low |
