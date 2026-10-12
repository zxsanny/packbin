# Loop 21 batch 01 report (waves 1a, 1b, 2 in one batch; one total review after)

Date: 2026-10-12. Commit 3acc589. Workers per package directory; package suites only (no per-batch review or Docker run, owner rule). Contract: `reference_loop21_slots.md` (TypeScript).

| Wave | Worker | Specs | Package suite |
|------|--------|-------|---------------|
| 1a | typescript | AZ-2382 (pinned, no code change), AZ-2390, AZ-2383, AZ-2391, probes AZ-2384/2386/2387 (AZ-2386 changed) | 865 to 880 incl. loader; strict `tsc` clean |
| 1a | cpp | AZ-2385, AZ-2390 (C++ share) | host and `gcc:16` green; arm: flash 8160 to 8152 B (margin 40 B), stack 448 to 456 B (margin 56 B) |
| 1a | csharp | AZ-2373, AZ-2389, AZ-2388, AZ-2393 | 1118 to 1310 |
| 1b | python | AZ-2381, AZ-2382, AZ-2383, AZ-2386, AZ-2390, probes | 846 to 977 |
| 1b | java | AZ-2382 (width fix), AZ-2383, AZ-2384, AZ-2386, AZ-2390, probes | 1952 to 2121 checks |
| 1b | rust | AZ-2382, AZ-2384, AZ-2386, AZ-2390, probes; then U5 late `when` fix | 569 to 625 |
| 1b | csharp (pass 2) | AZ-2382 (pinned), AZ-2383, AZ-2384, AZ-2386, AZ-2390, probes | 1310 to 1464 |
| 2 | fixtures | AZ-2394: 15 new cases | `check-cases.sh` ok: 55 |
| 2 | six loaders | AZ-2394 replay, AZ-2392 rule tables (python, java, rust, cpp) | TS 880, C# 1479, Java 2153, Python 1003, Rust all green, C++ host and `gcc:16` green |

Worker slips, all contained: none touched the index; the Rust and Python workers removed their own build artefacts; the TypeScript AZ-2391 timing test flaked once under parallel load and passed 3 of 3 on rerun.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear or unclear |
|---|---------------------|----------|-------------------|------------------|
| 1 | `bits`/`packed`/`sized` count in the row behind a clear `when` with NO value packs a clear bit (`010000`) in six, while U6 refuses the `times` shape with no value (reference row 56) | AZ-2387, D9 | decide: refuse in six (U11) | unclear |
| 2 | C# `List<double>` for an integer list builds and unpacks but pack refuses (`CollectionShape.HoldsRange`) | AZ-2373 | owner: refuse at construction or accept whole floats | unclear |
| 3 | Rust silently drops per-name `repeat` lists given without `__repeat__` groups (packs `01`) | AZ-2383 | refuse, or amend the AC to exempt Rust | unclear |
| 4 | Python refuses a lone value / a short required list / a `when` list outside `flags` in `repeat` (README: equal lengths) where TypeScript, Java, C#, Rust pack (rows 30, 31, 38) | AZ-2383 | align one way (pre-existing) | unclear |
| 5 | U3 was scoped to `repeat` only: `times` keeps accepting a short list under `flags` (README Times, AZ-2248); Rust refuses the list form under `flags` in `times` | AZ-2383, D8 | decide whether `times` follows | unclear |
| 6 | Java counts a nested-row group as one slot, TypeScript counts its members | AZ-2382 | align in the Go design / README exception | unclear |
| 7 | C++ empty-round check counts direct children only (an empty `when` body builds) | AZ-2390 | look through `when`, flash permitting | clear |
| 8 | Python unpack memory bound after removing the first-round surcharge (U1) | AZ-2381 | measure in step 14, README memory note | clear |
| 9 | Message and exception-class differences per package (Java `IllegalStateException`, Python `RuntimeError`, quoted members in C#) | U10 | accepted (U10 option B) | out-of-scope |
| 10 | AZ-2373 spec says 37 tests fail; 7 did | AZ-2373 | correct the spec text at step 13 | clear |
| 11 | Older TypeScript hostile schemes `row4_packed_*` pass `packed(2, ...)` (width 2) where the fixture README says width 1 | AZ-2394 | check the fixture schema against the README | unclear |
