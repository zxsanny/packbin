# Batch 06 report — loop 97 (assessment round 1 re-entry)

Tasks: AZ-3511 (Rust: mix error flags, optional and string field tests), AZ-3512 (Python, TypeScript, C#, Java tests), AZ-3513 (Go, Swift, C++ tests); 9 points; three workers on disjoint trees, re-run together by the parent. Source: `_docs/loops/loop97/assessment97.md` round 1, owner decision D4 (2026-11-01: make the Rust mix error unambiguous).

| Task | Status | Tests run by the parent after the join |
|------|--------|-----------------------------------------|
| AZ-3511 | Done | `run-suite.sh rust` exit 0 (1856 tests); `rust-m33f` pins unchanged (base 15,132/456, text 27,268/2,736, ecc 19,140/752, frame 20,404/1,728; the worker ran the embedded stage) |
| AZ-3512 | Done | pytest 4999 passed; `npm test` fail 0 and `tsc` clean; C# 5346 passed; Java `java/test.sh` exit 0 |
| AZ-3513 | Done | Go `-race` ok; Swift 455 tests in 80 suites; C++ `gcc:16` `make clean; make test` all passed |
| ring | — | full ring again after the Rust error type change: 64 pairs, 52,800 rows, 0 mismatched |

Review: inline read of the source diff (Rust `value.rs`/`ecc.rs`, C# `Ecc.cs`): 0 findings. CI-parity: PASS for the suites above.

Parent corrections after the workers: the C# mix message named only percentages ("25 and 0"); it now reads "25 percent and 25 parity bytes" as Java and TypeScript do (AC-19). AC-19 wording for Rust corrected: `UnpackError` has no text of its own, the two flags carry the distinction. Rust component doc updated.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AC-19 | The public Rust error type changed: every exhaustive pattern naming all fields of `MixedParity` needs the two flags (old tests updated; `hostile_tests.rs` uses `..`) | accepted by the owner (D4 option B); noted in `AGENT_GOTCHAS.md` | clear |
| AC-18 | The `PACKBIN_NO_TEXT` bytes variant of the string test is checked only by `-fsyntax-only` in C++ and is not run | accepted; the default build runs the string case | clear (Low) |
| AC-1 | A new scheme with an optional field had to be built in each package (no existing test scheme had 13 and 10 clear bytes) | accepted | clear |
