# Feature — flash search, held-`when` fold retry, corpus guards, flash pin

Total 10 points, four tasks. Epic AZ-2645. Source: `problem.md`, `acceptance_criteria.md`, `scenarios.md` in this folder.

1. **A, flash search (3 points).** Find at least 40 B of flash in `cpp/src/core` and `cpp/include/packbin` so the Cortex-M4F image is at most 8,040 B (8,080 B today), with every packet and refusal of the shared corpora unchanged and no stack figure higher (504 / 500 / 436 B). A smaller saving is reported with the figure; AC-1 is then recorded as not met, never loosened. No wire change.
2. **B, fold retry (3 points, after A).** Try the `When` and `FlagBit` handling of `unpack_children` and `unpack_one` as one function with `unpack_held` inlined into `unpack_children` and no larger frame. Kept only if flash is at most 8,080 B and the three chain stacks are not above 504 / 500 / 436 B; else restore and record the figures (accepted outcome). No depth limit, no wire change.
3. **C, corpus guards (3 points, independent).** Plain Rust loader names an unused unpack or limit handler by case id; the Rust nostd test notices a case moving between run and a reasoned skip, by id (expected-skip set); Swift and Rust nostd corpus counts derive from the corpus file; Go merges `idDifference` and `sameSet` into one helper. Each shown with a broken copy.
4. **D, flash pin (1 point, after B).** The arm stage fails when the Cortex-M4F flash is above a pinned figure (the one recorded after A and B), naming measured and pinned bytes; shown on a copy with the pin one byte below. Margins written to `AGENT_GOTCHAS.md` and the C++ description.

## Scenarios

See `scenarios.md` (all rows confirmed, X1 and X2 out of scope).

## Fit decisions

None: no wire or public API change. `static_assert(offsetof(Field, eq) == 16)` must hold.
