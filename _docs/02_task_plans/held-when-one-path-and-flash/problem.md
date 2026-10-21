---
loop: 56
branch: dev
---

# Held-`when` single path, C++ flash saving, derived corpus counts (loop 56)

Source: `_docs/loops/loop55/handoff56.md` (candidates "Flash first", "One path for held whens", "Corpus counts") and the loop 55 review (findings #1, #2, #5). The owner chose all three on 2026-10-21 ("Accept recommended for loop 56"); the code areas below are the ones named in that question. The hopper was empty; the interview is that choice plus the evidence below.

## Problem

1. **Flash first (review #2, Low).** `reads_flag_byte` (`cpp/src/core/unpack.cpp:48`) rescans the entries of a `when` on every `unpack_children` call that meets a held `when`. The answer is fixed when the scheme is resolved, so it could be one bit in `Field`. The Cortex-M4F flash budget is 8192 B with a **72 B margin** (8120 B); any other C++ edit needs a saving in `cpp/src/core` first.
2. **One path for held whens (review #1, Medium).** The `when` and flag-bit handling is written twice: in `unpack_children` and in the `Kind::When` / `Kind::FlagBit` cases of `unpack_one` (still reached by `unpack_table`, a `times` round and a flags member). Fold them into one function if the flash allows. The stack of a chain reached through a `times` round is not measured yet.
3. **Corpus counts (review #5, Low).** The case counts are hard-coded in the Go, Swift and Rust no-heap/hostile loaders (`go/hostile_loader_test.go:309`: 75; `swift/Tests/PackbinTests/HostileTests.swift:47`: 75; `swift/.../FuzzTests.swift:26`: 17; the Rust loader to be found at task time). Adding a line to `fixtures/hostile/cases.txt` breaks them for the wrong reason.

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-21. No UI.

| Work | Place |
|------|-------|
| Flash saving, single path | `cpp/src/core/unpack.cpp` (`reads_flag_byte`, `unpack_children`, `with_outer_flags`, `unpack_one` cases `When` and `FlagBit`), `cpp/include/packbin` (`Field`), the scheme resolver that fills `Field`, `cpp/embedded/` (flash and stack probe), `_docs/AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md` (margins) |
| Corpus counts | `go/hostile_loader_test.go`, `swift/Tests/PackbinTests/HostileTests.swift`, `FuzzTests.swift`, the Rust loader in `rust/src` that reads `fixtures/hostile/cases.txt` |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The flash saving may be too small to pay for the fold | do the saving first and measure; if the fold does not fit, keep it for a later loop and say so | open | Medium |
| A resolve-time bit grows `Field` (RAM/flash of the tables) | measure on the all-kinds image; a bigger table is a regression | open | Medium |
| Stack margin is 8 B; the fold may deepen the walk | measure the 3-deep chain (504 B) and the flag-byte chain (500 B) on the arm image before and after | open | Medium |
| Wire packets must not change | the differential and hostile corpora of all eight packages are the proof | open | High |
| Row U24 and the first `v*` / `go/v*` tags | owner decides separately | accepted-risk | Low |
