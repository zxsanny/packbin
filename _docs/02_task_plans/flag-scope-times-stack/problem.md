---
loop: 67
branch: dev
---

# Stack of a flag scope inside a `times` round (loop 67)

Source: `_docs/loops/loop66/handoff67.md` (candidate "Stack of a flag scope inside a `times` round"). The hopper was empty; on 2026-10-24 the owner chose this candidate from a four-way question (option text: "Measure shapes on a tree copy, then cut the 612 B unpack stack (`stack_pin`) if a shape wins. Code: `cpp/src/core/unpack.cpp`, `pack.cpp`; arm embedded stage. No named consumer yet; may end as a measured no-go.").

## Code sections / UI locations for this loop

Owner's words: "cpp/src/core/unpack.cpp, pack.cpp; arm embedded stage". No UI. `stack_pin` and the all-kinds image (scheme 0x5e) in `cpp/embedded/`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Any figure in an AC is read from a run on HEAD in this loop | `AGENT_GOTCHAS.md` (loops 60, 62, 63) | open | Medium |
| Flash margin (468 B) may be spent by a stack saving | measure both; a shape that raises flash needs a line saying what the bytes bought | open | Medium |
| The loop may end as a measured no-go | record the table and stop; no stand-in change | open | Low |
