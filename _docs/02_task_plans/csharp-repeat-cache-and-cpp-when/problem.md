---
loop: 54
branch: dev
---

# C# repeated-text cache and C++ `when` of a skipped source (loop 54)

Source: `_docs/loops/loop53/handoff54.md` (candidate "C++ `when` of a skipped source", found in loop 51) and the CI read of loop 53 (`main` run 39537652411 red on a C# suite). The owner chose both for this loop on 2026-10-21 ("also c# fix"), and confirmed the intake summary and the code locations below ("yes go on"). The hopper was empty; the interview is the owner's two decisions plus the evidence below.

## Problem

1. **C# misses its own 1 s bound on the CI runner.** `CompactTextTests+RepeatedTextSpeed` (AZ-2737, CS-D7: one 65,535-character text in 200 rounds of `times`, packed and unpacked within 1 s nominal) failed on `main` in loop 49 (run 39384081368: 1.083 s and 1.015 s) and in loop 53 (run 39537652411: 1.070 s and 1.023 s), both times in the second dotnet step (`PackbinTarget=netstandard2.0`), both times at load factor 1.00, so the bound was a strict 1.000 s; `dev` was green in both loops and loop 49 recorded the failure as an unproven flake. On this Mac the test takes 0.89 to 1.00 s on both targets. Cause: `PackUtf8` (`csharp/Walker.Counted.cs`) runs the optimal text parse in every round (about 5 ms each, 1.058 s of the 1.070 s is pack). Java, Python, TypeScript, Go, Swift and Rust keep the encoded text of the previous round inside one pack call and reuse it when the text is equal; C# has no such reuse, and loop 46 recorded it as "met 1 s unchanged" from an idle run, with no headroom.
2. **The C++ core packs a body that its own unpack refuses.** A `when` whose source field sits inside a `when` that does not hold is still matched against the source's value in the row. `u8 mode=0; when(mode==1){u16 a; u8 k=2}; when(k==2){u8 b=5}` packs `21 00 05` and `unpack` fails with `TrailingBytes` (`gcc:16`, loops 51 and 52). The reference behaviour is the other packages': a source that is not written is absent, so the `when` is false (std Rust and the new Rust core write `21 00`; the Python package, run on 2026-10-21, writes `01 00` for the same scheme and for the variant with `k==0`, and unpacks both to `{mode: 0}`). The same check exists for counts (`count_skipped` in `cpp/src/core/pack.cpp`, `mark_held` in `cpp/include/packbin/order.hpp`); `when` lacks it. No other package has been run on the probe yet.

## Code sections / UI locations for this loop

From the owner's confirmation of 2026-10-21. No UI.

| Work | Place |
|------|-------|
| C# repeated-text cache | `csharp/Walker.Counted.cs` (`PackUtf8`, the only text call site of a field), `csharp/PackOut.cs` (the object one pack call owns), `csharp/tests/CompactTextTests.Repeat.cs` |
| C++ `when` of a skipped source | `cpp/src/core/pack.cpp` (`count_skipped`, `pack_one` `Kind::When`), `cpp/src/core/values.cpp` (`when_matches`), `cpp/src/core/unpack.cpp` (its `Kind::When` case), `cpp/include/packbin/order.hpp` (`mark_held`, `resolve`) |
| Shared hostile case and the other packages | `fixtures/hostile/cases.txt` and the runners of the eight packages (`python/tests`, `typescript/tests`, `java/src/test`, `csharp/tests`, `rust/src` + `rust/tests`, `go/`, `swift/Tests`, `cpp/tests/core`) |

The Cortex-M4F margins of `_docs/AGENT_GOTCHAS.md` bind the C++ edit (272 B flash, 8 B stack): a flash or stack saving comes first when the change does not fit. No wire change in either task.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The C++ edit may not fit the Cortex-M4F margins (272 B flash, 8 B stack) | measure on the arm embedded stage before the commit; a saving elsewhere in `cpp/src/core` first (`AGENT_GOTCHAS.md`) | open | Medium |
| C++ unpack reads a skipped source as 0, so `when(k==0)` would match on unpack while pack writes nothing | AC-W2 pins it; unpack must treat a skipped source as absent, as pack does | open | Medium |
| The shared case may fail in a package other than C++ (only Python and Rust are known to pass) | a failing package is fixed here when it is the same defect, else ticketed; never skipped | open | Medium |
| The CI-only failure shows on `main` and not on `dev` in two loops | cause of the difference is unproven (runner noise on the second push is a guess); the fix removes the near-miss for both | accepted-risk | Low |
| Row U24 (the C++ runner skips three `pack_novalue_count_clear_when_*` cases the Rust core refuses) | owner decides separately; not part of this loop | accepted-risk | Low |
