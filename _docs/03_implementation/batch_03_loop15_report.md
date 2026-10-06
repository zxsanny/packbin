# Batch Report

**Batch**: 3 (loop 15)
**Tasks**: AZ-2220_round_limits_hostile_and_docs
**Date**: 2026-10-06

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2220_round_limits_hostile_and_docs | Done (AC-1 to AC-9); one deviation: `blackbox-tests.md:1589` says 17 of the 19 cases because C++ skips the two `limit` cases | `fixtures/hostile/{cases.txt, check-cases.sh, cases.test.sh, README.md}`, replays `csharp/tests/HostileVectorTests.cs`, `typescript/tests/{hostile.test.ts, support/hostile-cases.ts}`, `java/src/test/java/packbin/HostileVectorTest.java`, `rust/src/hostile_tests.rs`, `cpp/tests/core/hostile_host_tests.cpp` (two-line skip, test file only), `README.md`, `_docs/02_document/tests/blackbox-tests.md`, `_docs/05_security/{security_report.md, owasp_review.md}` (F10 and F11 status lines; the loop's audit rewrites them) | hostile cases ok: 19; C# 410 (407 + 3), TypeScript 279 (276 + 3), Rust 234, Java all runners, Python 103 (includes the README test), C++ all passed | none open |

## Decisions

- A new `limit` stage in `cases.txt` with two ids: `repeat_rounds_over_limit` (`0111223344`) and `times_rounds_over_limit` (`010411223344`), expected `too_many|bad_value`. Each replay builds its scheme by hand with a low round limit of 3 and expects the interim error with `needed` 0 and `left` 1 (the byte of the round that would start) and no handler call. The 17 older lines are unchanged; Python and C++ skip the stage (C++ unpacks into fixed arrays and has no limit; Python keeps only values it read).
- README: the intro of Untrusted input no longer promises memory "set by the length of the packet"; a limits bullet (names, defaults, what is counted, the interim error, how to raise them in each package, why C++ and Python need none), a memory bullet with measured figures (TypeScript 86 MiB, C# 86 MiB, Java 92 MiB refused at round 65,536 against about 400, 530 and 560 MiB unlimited; Rust `times` one-byte 21 MiB against about 310; Rust eight flag bits 64 MiB against 1.3 to 1.4 GiB; Python 36 MiB, unchanged), an upgrade paragraph that includes the `WithLimits` reset caveat, and one pointer sentence each at Repeat and Times.

## Code Review Verdict: PASS_WITH_WARNINGS

Parent read the README diff, the case file, the Rust, TypeScript and C++ replay changes and the checks. The worker's mutation proofs (scratch copy of the tree): removing the check in each package fails its limit replay (C# 2, TypeScript 2, Java 6, Rust panics "unpack returned a value"); an unknown `limit` id fails all four replays; without the C++ skip the C++ suite fails. No separate `/code-review` run for this tests-and-docs batch. Warnings:

- The slot count per round still differs by package (C# distinct names, TypeScript names of the round, Java value fields, Rust fields); the README says a packet right at the slot limit can pass in one package and fail in another (review finding 3 of batch 1). The hostile cases use the rounds limit, not the slot limit.
- Strict `tsc` is not run over the TypeScript tests (missing Node types and older implicit anys; CI checks only `src`).
- `cases.test.sh` asserts the literal 19: AZ-2194 (five `pack` cases, count 22) will conflict on that line; the second task to land rebases the count and the stage list.

CI-parity: PASS locally. The same 13-stage run as batches 1 and 2, by the parent, one stage at a time: C# 410, TypeScript 279, Python 103, Rust 234, C++ and Java passed, `cpp-embedded` 4 of 4, `cpp-embedded-esp` 4 of 5 (Pico fails on this arm64 host by design), `cases.test.sh` and `check-cases.sh` (19), `report-row.test.sh`, `publish-gate.test.sh` (377 s), strict `tsc`, `language-pair.sh` (61 s). 12 of 13 passed.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `blackbox-tests.md:1589` counted C++ cases; C++ runs 17 of the 19 | AZ-2220 AC-9 | Wrote what is true (17 of the 19) | clear |
| 2 | The README now says Python uses about 36 MiB for the packet, measured with Python 3.14; it replaces the loop 13 citation of 33 MB | AZ-2220 | None | clear |
| 3 | A zero limit throws in C#, TypeScript and Java but panics in Rust | AZ-2220 AC-8 | Stated in the README; error kind (C15) unchanged | clear |
| 4 | AZ-2194 will conflict on the `cases.test.sh` literal | AZ-2220 Risk 2 | Second task to land adjusts | clear |

## Commit

`[AZ-2220] Round limits: hostile cases, README`. Body: one line + `Loop: 15`.

## Next: all seven tasks done; feature assessment (step 10.5)
