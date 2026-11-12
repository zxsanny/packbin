# Code Review Report

**Batch**: AZ-4210 to AZ-4219 (epic AZ-4209) | **Date**: 2026-11-12 | **Loop**: 113 | **Verdict**: PASS_WITH_WARNINGS (after the fix round; the first pass was FAIL on one High finding, documents only)

One total review for the loop (owner rule 2026-10-06), by three read-only reviewers over disjoint parts, each running its own probes against the packages, and the parent. Part A: AZ-4210 shared cases and README, TypeScript, Python, Dart. Part B: C#, Java, Go, Swift. Part C: Rust, C++. A fourth read-only probe checked the shape "a repeat inside a row or group of a round" in the six packages that had not been probed.

The walk made no wrong decision in any scheme any reviewer tried (about 30 shapes in TypeScript, Python and Dart; 13 common schemes in five packages; random trees against an independent oracle of the contract: 420,000 in Rust, 1.1 million in C++). The first pass found one High, one Medium and 17 Low findings; all but the accepted items below were fixed in batch 2.

## Findings

| # | Severity | Category | Where | Title | Disposition |
|---|----------|----------|-------|-------|-------------|
| A-F1 | High | Spec-Gap | `README.md`, `repeat-last.md`, `fixtures/hostile/README.md` | Dart's nesting rule did not look into a nested row of a round; four sentences untrue for Dart | Fixed: contract 1.0.2, README, hostile README (parent). Dart refuses the repeat there with the contract's round text; a `times` there still builds |
| B1 | Medium | Maintainability | `java/.../Rounds.java`, `Walker.java` | Code only an inner repeat could reach left in pack and unpack | Fixed (Java fix round): `outer`, `nested`, `entryCounts`, `foldIntoOuterRound` and the repeat arms removed; times code unchanged |
| A-F2, B3 | Low | Performance | TypeScript `rounds.ts`, Dart `checks.dart`, Swift `Counted.swift` | Follower look-up at every container made the walk quadratic on a run of containers that write nothing (16,000 siblings: 1.3 s TypeScript, 2.6 s Dart; 8,000: 380 ms Swift) | Fixed in all three (one pass, follower carried forward); 16,000 siblings now 4 ms (TypeScript), 28-35 ms (Dart), 8,000: 13-20 ms (Swift); a timing test in each with the package's load-aware helper (Dart got a new helper) |
| A-F3 | Low | Style | `python/.../_scheme.py` | Python ran the rule before the duplicate-name rule | Fixed: call moved after names and element accessors, pinned |
| A-F4 | Low | Maintainability | `dart/lib/src/checks.dart` | `checkRepeatLast` 64 lines | Fixed (37 / 24 / 34 lines) |
| A-F5 | Low | Maintainability | TypeScript, Python, Dart tests | Refusal texts and helpers written twice | Fixed: one support module per package |
| A-F6, B8 | Low | Style | tests in six packages | Comments told history ("until loop 113") | Fixed in TypeScript, Python, Java, Swift, C#, Go, Rust; the "Loop 113 (AZ-xxxx)" origin labels of Swift hostile files stay (they name where the cases came from) |
| A-F7 | Low | Maintainability | `dart/test/rounds/hostile_rounds_test.dart` | The random-bytes layout lost its repeat under a flag bit | Fixed: a fourth layout `flagRepeat()` |
| A-F8 | Low | Spec-Gap | `README.md`, `repeat-last.md` | "Everything else counts" omitted a `times` or `repeat` whose body writes nothing; status line stale | Fixed |
| B2 | Low | Spec-Gap | Java, Swift tests | The pack round cap inside a list element lost its only test | Fixed: the `times` form in both |
| B4 | Low | Style | TypeScript, Swift | Two violations at once named the follower where C#, Go, Java, Python name the element | Fixed: the body of a repeat is walked first in TypeScript, Swift and Dart; all now answer with the first violation in document order |
| B5 | Low | Style | `java/.../SchemeOrder.java` | Java named the last repeat met, the others the first | Fixed with the test Go has |
| B6 | Low | Style | Java, C# | Which rule answers first when a scheme breaks two different rules differs | Accepted: all refuse, the contract fixes no order; Python was moved to the TypeScript and Dart order |
| B7 | Low | Maintainability | `java/.../SchemeOrder.java` | `kindAndId` and `bitName` repeat each other | Fixed: one `named(kind, field)` helper; message texts unchanged |
| C1 | Low | Spec-Gap | contract invariant, AZ-4218 NFR | "Costs nothing per pack or unpack" untrue for the Rust heap-free API (`validate` runs first in pack and unpack) | Fixed: contract and README say it; the gotchas line says what the 104-112 B bought |
| C2 | Low | Maintainability | probes README | Did not say why `b-unbound` and `c-unbound` print | Fixed |
| C3 | Low | Maintainability | `rust/tests/nostd_repeat_last_tests.rs` | No heap-free case for `dict` or `utf8` after a repeat | Fixed |
| C4, C5 | Low | Style | Rust tests | Two tables over 50 lines; one expected hex without a note | Fixed: tables split, comment added |

## Special claims confirmed by reviewers

- Every acceptance criterion of the ten specs traces to code and to a test that fails when the check is switched off (the check was switched off by hand in every package; 27 to 105 tests failed each time; all 11 C++ compile-fail files then compile).
- The check runs for every public way to build a scheme in every package; it reads no row; no packet changes (K1 to K5 and the shared pack cases give the contract's bytes on the unchanged code and after).
- The "before" packets of R1 to R8 in `fixtures/hostile/README.md` reproduce on TypeScript at `d5d6874`.
- Tests removed or rewritten (counts for AC-4 of each package): TypeScript 4 in 3 files, C# 1, Python 3, Java 17 in 6 files, Go 5 in 4 files (plus 1 of 30,000 random schemes), Swift 4 in 4 files, Dart 1, Rust 5 in 3 files, C++ 0. Every behaviour they pinned is still pinned somewhere (named per package in the reviewers' reports) or cannot be reached any more.

## Outside the diff, queued

- C#: the bit of a `flags` that is a direct member of a `flags` is never set (`csharp-flags-in-flags-presence`).
- Arduino-ESP32 core of the ESP stage is unpinned (`esp-core-arduino-pin`).
- Dart: fixed wall-clock bounds in `colliding_keys_test.dart` (`dart-colliding-keys-timing-helper`); a 5,000-deep `when` chain overflows the stack at build, before and after this loop (`dart-deep-when-chain-stack-overflow`).
- Not verified by the reviewers: the full suites, the device pins and the ESP and Uno rows; the parent runs them in step 11.
