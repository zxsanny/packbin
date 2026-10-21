---
loop: 55
branch: dev
---

# `when` chain stack, bool source behind a clear `when`, repeated-text headroom (loop 55)

Source: `_docs/loops/loop54/handoff55.md` (candidates A, B, D) and the review of loop 54 (findings #1 and #3). The owner chose all three on 2026-10-21 ("Accept all recommended: A+B+D"); the code areas below are the ones named in that question. The hopper was empty; the interview is that choice plus the evidence below.

## Problem

1. **A: nobody has measured the stack cost of a deep `when` chain.** `when_matches` and `source_skipped` (`cpp/src/core/values.cpp`) call each other once per enclosing `when` of a source, so the stack grows with the chain. The all-kinds Cortex-M4F image has one `when` and no chain (`cpp/embedded/common/all_kinds.cpp:20`), so its 504 B of the 512 B budget (8 B margin) does not show the cost. A scheme with a source three `when`s deep may exceed 512 B on the device and no stage would say so.
2. **B: a bool or group-presence source behind a clear `when` has no test.** `mark_held` now marks these sources too (loop 54). Python gives, for `u8 mode; when(mode==1){ flags{ bool on }; u8 a }; when(on==true){ u8 b }`: mode 0 packs `00` (after the scheme id) and unpacks to `{mode: 0}`; mode 1 with `on` true packs `01 01 07 05`; mode 1 with `on` false packs `01 00 07`. The other seven packages have not been run on it.
3. **D: a speed test within 10% of its bound fails on the runner (C#, loops 49 and 53); the other packages were never checked for headroom.** CI figures of `dev` run 39548740720 for the case "one 65,535-character text in 200 rounds of `times`": Java 0.029 s pack and 0.019 s unpack, Rust 0.040 s and 0.009 s (load factor 2.60), C++ 0.013 s and 0.013 s (3 s nominal bound), TypeScript 268 ms. Python passes but prints no time. Go has no test of this case (its nearest is 2000 rounds of a 10,000-byte text, 500 ms bound). Swift has a lone 65,535-byte text and no 200-round case.

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-21 (A+B+D). No UI.

| Work | Place |
|------|-------|
| A: `when` chain stack | `cpp/src/core/values.cpp` (`when_matches`, `source_skipped`), `cpp/embedded/common/all_kinds.cpp` and `.hpp` (the image), `cpp/embedded/arm.sh` (stack measurement), `_docs/AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md` (margins) |
| B: bool source behind a clear `when` | `fixtures/hostile/cases.txt` (new cases) and the runners of the eight packages (`python/tests`, `typescript/tests`, `java/src/test`, `csharp/tests`, `rust/src` + `rust/tests`, `go/`, `swift/Tests`, `cpp/tests/core`); a package that differs is fixed where it differs |
| D: repeated-text headroom | `python/tests/test_compact_text.py` (HD-2 test), `go/` (new test file), `swift/Tests/PackbinTests/TextSpeedTests.swift`, the existing tests of Java, TypeScript, Rust and C++ (`java/src/test/java/packbin/TextRepeatSpeedTest.java`, `typescript/tests/compact-text.test.ts`, `rust/src/text_repeat_tests.rs`, `cpp/tests/core/text_repeat_host_tests.cpp`) |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The chain image may exceed 512 B on the Cortex-M4F (margin is 8 B) | measure first; if over, a saving elsewhere in `cpp/src/core` or a non-recursive check; a depth limit would be a new scheme refusal and goes to the owner | open | Medium |
| A package may differ on the bool/group probe (only Python is known) | fix it in this loop when it is the same defect; else ticket, never skip | open | Medium |
| A package may be above half its bound on D | fix in this loop if the change is local to the walker (as AZ-2815); else ticket for loop 56 | open | Low |
| Go and Swift have no 200 x 65,535 test; the new test may fail on the first run | a failing Go or Swift run is a finding, fixed or ticketed, never loosened | open | Low |
| Row U24 (three C++ runner skips) and the first `v*` / `go/v*` tags | owner decides separately | accepted-risk | Low |
