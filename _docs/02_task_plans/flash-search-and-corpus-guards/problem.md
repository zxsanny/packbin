---
loop: 57
branch: dev
---

# Flash search, held-`when` fold retry, corpus guards, flash pin (loop 57)

Source: `_docs/loops/loop56/handoff57.md` (candidates "Flash search, then the fold", "Corpus guards", "Flash bound check") and the review of loop 56 (finding #1 Medium, the Lows). The owner chose "Accept all recommended" on 2026-10-22. The hopper was empty; the interview is that choice plus the evidence below.

## Problem

1. **Flash search (C++).** AZ-3143 missed its target: the Cortex-M4F flash image is 8,080 B (margin 112 B) against the 8,040 B asked. Any edit to `cpp/src/core` or `cpp/include` needs a saving first. The owner accepted the gap and carried the search to this loop.
2. **Held-`when` single path (C++).** The `When` and `FlagBit` handling lives twice, in `unpack_children` and in the `When` / `FlagBit` cases of `unpack_one` (review #1 of loop 55, Medium). The fold was tried in loop 56 as one NOINLINE `unpack_held` and not kept: 8,140 B flash (+60 B) and 676 B net stack (limit 512 B), because the loop calls an out-of-line function per `when` and each level gets a frame. A retry needs `unpack_held` inlined into `unpack_children` without a bigger frame, and about 60 B of flash saved first.
3. **Corpus guards (Go, Swift, Rust test loaders).** Four weaknesses left by AZ-3145: the plain Rust loader (`rust/src/hostile_tests.rs`: `scheme_for`, `rust_outcome` are `match` expressions) cannot name an unused unpack or limit handler; a Rust nostd case that moves from run to a reasoned skip is not noticed since the counts were removed; `corpus.txt` counts are still hard-coded (Swift `FuzzTests.swift` `corpus.count == 33`, Rust nostd `inputs.len() >= 33`); Go has two helpers for one check (`idDifference` and `sameSet`).
4. **Flash pin.** Nothing asserts the recorded flash figure. The arm stage fails only above 8,192 B, so a later edit can spend the whole margin without any stage saying so.

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-22 (all recommended). No UI.

| Work | Place |
|------|-------|
| Flash search and fold retry | `cpp/src/core/` (`unpack.cpp`, `pack.cpp`, `values.cpp`, `session.cpp`), `cpp/include/packbin/`, `cpp/embedded/` (`arm.sh`, `common/all_kinds.cpp`), `cpp/tests/core`, `_docs/AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md` (margins) |
| Corpus guards | `rust/src/hostile_tests.rs`, `rust/tests/nostd_hostile_tests.rs`, `swift/Tests/PackbinTests/FuzzTests.swift` (and `HostileTests.swift` if it holds a count), `go/hostile_loader_test.go`, `go/hostile_pack_test.go`, `fixtures/hostile/cases.txt` and `corpus.txt` (read only) |
| Flash pin | `cpp/embedded/arm.sh`, `cpp/embedded/lib.sh` |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The search may find less than 40 B | report the figure; AC-1 not met means a ticket, not a loosened bound | open | Medium |
| The fold may fail again (flash or stack) | allowed outcome: not made, figures recorded; a depth limit or a wire change is never the answer (owner decides) | open | Medium |
| Stack margin is 8 B: any edit to `unpack.cpp` / `pack.cpp` may deepen the walk | measure with the arm stage before the commit | open | Medium |
| A flash saving by removing a check would change behavior | packets and refusals must stay identical on the shared corpora | open | High |
| The Rust nostd skip guard needs an expected-skip list that can go stale | the list names ids and reasons; a stale entry fails by id | open | Low |
| Row U24, the first `v*` / `go/v*` tags, size limits, CS-D5, F44, epic AZ-2750 | owner decides separately | accepted-risk | Low |
