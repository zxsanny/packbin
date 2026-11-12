# Batch Report

**Batch**: 2 and 3 (loop 113): the packages of the epic, the review fixes and the extension round
**Tasks**: AZ-4211_repeat_last_typescript, AZ-4212_repeat_last_csharp, AZ-4213_repeat_last_python, AZ-4214_repeat_last_java, AZ-4215_repeat_last_go, AZ-4216_repeat_last_swift, AZ-4217_repeat_last_dart, AZ-4218_repeat_last_rust, AZ-4219_repeat_last_cpp, AZ-4232_repeat_last_group_in_round_cases
**Date**: 2026-11-12

Commits: `e1e85d1` (TypeScript, C#, Python, Java, Go, Rust), `9239873` (Swift, Dart), `4927d4a` (C++), `3b548f3` (review fixes), then the extension round commit. Batch 1 (`d5d6874`, AZ-4210) has its own report.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4211 TypeScript | Done | `typescript/src/rounds.ts` (500), `index.ts`, 8 test files, probe `rule-count/run.sh` | `npm test` 3,700 passed (3,655 before, 14 failing on the new ids); strict `tsc` clean; rule count 0 (77,277 schemes) | none |
| AZ-4212 C# | Done | `csharp/RoundScopes.cs`, 5 test files | 5,474 passed on `net10.0` and `netstandard2.0` (5,394 before, 11 failing) | none |
| AZ-4213 Python | Done | `python/src/packbin/_validate.py`, `_scheme.py`, 8 test files | `run-suite.sh python` 5,128 passed (5,012 before, 15 failing) | none |
| AZ-4214 Java | Done | `SchemeOrder.java`, `Rounds.java`, `Walker.java`, 11 test files | `java/test.sh` `PackbinTest checks: 70945` (70,826 before on the old cases), 12 mains, api-check PASS | one `AC-8` timing flake under load (see below) |
| AZ-4215 Go | Done | `counted.go`, `scheme.go`, `doc.go`, 10 test files | `run-suite.sh go` 6 steps green (323 s); race step 399 tests | none |
| AZ-4216 Swift | Done | `Counted.swift`, `Packbin.docc/Packbin.md`, 9 test files | `run-suite.sh swift` 467 tests in 82 suites passed (455 before, 14 issues) | none |
| AZ-4217 Dart | Done | `checks.dart`, `build.dart`, `fields.dart`, `CHANGELOG.md`, 12 test files incl. new `support/timing.dart` | `run-suite.sh dart` +2,088 passed (+2,004 before, 4 failing) | none |
| AZ-4218 Rust | Done | `field/round_body.rs`, `map_scheme.rs`, `nostd/check.rs`, `nostd/scheme.rs`, 14 test files, `rust/embedded/limits-m33f.txt` | compose `rust` 1,931 passed (1,924 before the review fixes); `rust-embedded` 0 targets failed | pins +104 to +112 B flash (see below) |
| AZ-4219 C++ | Done | `order.hpp`, `fields_counted.hpp`, `Makefile`, 11 compile-fail files, 4 test files | clang and `gcc:16` `make test` green; `cpp-embedded` 5 rows PASS; ESP core 0 targets failed | none |
| AZ-4232 shared loader cases | Done | `fixtures/hostile/cases.txt` (+2), README sections, nine hostile loaders | 90 cases ok; the nine loaders replay both ids (counts in the per-package lines above) | none |

AC-4 counts (own test schemes the rule refused, each rewritten with `times`, turned into a refusal test or kept as a test of the old behaviour's replacement): TypeScript 4 in 3 files, C# 1, Python 3, Java 17 in 6 files, Go 5 in 4 files (plus 1 of 30,000 random schemes), Swift 4 in 4 files, Dart 1, Rust 5 in 3 files, C++ 0; README code blocks 0.

## Code Review Verdict: PASS_WITH_WARNINGS

`_docs/03_implementation/reviews/batch_01_loop113_review.md` (one total review by three read-only reviewers; 1 High, 1 Medium and 17 Low in the first pass, all fixed except the accepted ones named there). Fix round commit `3b548f3`.

## Test Suite

Per package: see the Task Results table. The loop's one total run (`scripts/loop-tests.sh`, step 11) is recorded in `_docs/loops/loop113/record113.md`. CI-parity: each package's CI-way suite (`run-suite.sh <package>`, the Rust and Go ones in their containers) ran at its last change.

Device figures (Rust, Rust 1.98): base 15,132 to 15,244 B flash, text 27,268 to 27,372, ecc 19,996 to 20,100, frame 20,404 to 20,516; stack 456, 2,736, 664, 1,728 unchanged; the pins of `limits-m33f.txt` are set to the measured figures. C++: M33F 25,948 B / 740 B, frame image 8,416 B / 912 B, small image 22,280 B, Uno 15,402 B / 196 B RAM, all unchanged.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Dart's nesting rule did not look into a nested row: `repeat` or `times` holding a nested row with a repeat built, packed `0102050607`, and read back wrong or was refused by its own unpack | AZ-4217, contract rule 3 | Dart refuses it with the contract's round text; contract 1.0.2; a `times` there still builds in Dart | clear (rule 3 says it) |
| 2 | C++ built a `repeat` inside a group of a round and read back other values with no error | AZ-4219 AC-5 | refused (`SchemeInvalid`, compile error for `constexpr`); pinned by compile-fail files | clear |
| 3 | The Rust heap-free API pays the new pass on every pack and unpack (`validate` runs first) | AZ-4218 NFR "nothing per pack or unpack" | contract and README say it; `_docs/AGENT_GOTCHAS.md` records the 104 to 112 B | clear |
| 4 | A scheme that breaks two parts of the rule at once got different texts per package | contract (no order fixed) | all nine name the first violation in document order (fix round) | clear |
| 5 | The follower look-up was quadratic on a run of containers that write nothing (TypeScript, Dart, Swift) | AC "one walk" | one pass in all three; timing tests with load-aware helpers | clear |
| 6 | Dart had no load-aware timing helper | none | `dart/test/support/timing.dart`; queue item for the one remaining fixed bound | clear |
| 7 | The probe tool `rule-count/run.sh` copied `HEAD`, where the suite fails on the new ids | AZ-4211 AC-5 | copies the checkout | clear |
| 8 | C# never sets the bit of a `flags` that is a direct member of a `flags` (values dropped, no error) | none (outside this diff) | queue item `csharp-flags-in-flags-presence` | clear |
| 9 | The ESP stage installs the newest unpinned Arduino-ESP32 core (525 s) | none | queue item `esp-core-arduino-pin` | clear |
| 10 | A 5,000-deep chain of nested `when`s overflows the stack when a Dart scheme is built (before and after) | none | queue item `dart-deep-when-chain-stack-overflow` | unclear (needs a limit decided for all nine) |
| 11 | `repeat(v), times(n, bytes z size 0)` builds by the contract's table; its own unpack refuses a packet with `n` above 0 by the older zero-width rule | contract table | not caused by the rule (`n, times(n, bytes z 0)` alone is refused the same way); left | unclear (is a zero-width `times` body worth refusing at build?) |
| 12 | Java `AC-8` (100,000 round trips) took 1.404 s against a 1.019 s bound at host load about 14 in one run | none | recheck in step 11; a timing bound that is not load-scaled enough | unclear |

## Commit

`[AZ-4232] Shared cases for a repeat in a group of a round, replayed by nine loaders` (body one line + `Loop: 113`).

## Next Batch: All tasks complete
