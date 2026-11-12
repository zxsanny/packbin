# Feature assessment — loop 113

loop: 113
feature: repeat-must-be-last
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-11-12
**Implement pass**: batches 01 and 02 (`_docs/03_implementation/batch_01_loop113_report.md`, `batch_02_loop113_report.md`), review `_docs/03_implementation/reviews/batch_01_loop113_review.md`; the workers' per-task reports are summarised in the batch reports
**Verdict**: EXTEND — 18 covered / 3 out-of-scope / 1 gap-clear / 0 gap-unclear

The rule is the contract `_docs/02_document/contracts/library/repeat-last.md` (1.0.2). "Production code path" is the scheme check of each package: TypeScript `rounds.ts` `validateRepeatLast`, C# `RoundScopes.cs` `CheckLast`, Python `_validate.py` `_validate_repeat_last`, Java `SchemeOrder.java` `repeatLast`, Go `counted.go` `checkRepeatLast`, Swift `Counted.swift` `checkRepeatLast`, Dart `checks.dart` `checkRepeatLast`, Rust `field/round_body.rs` `check_repeat_last` and `nostd/check.rs` `repeat_last`, C++ `order.hpp` `detail::check_repeat_last`. Test evidence is the per-package `repeat-last` tests (TypeScript `repeat-last.test.ts`, C# `RepeatLastTests.cs`, Python `test_repeat_last.py`, Java `RepeatLastTest.java`, Go `repeat_last_test.go`, Swift `RepeatLastTests.swift`, Dart `repeat_last_*_test.dart`, Rust `repeat_last_tests.rs` and `nostd_repeat_last_tests.rs`, C++ `repeat_last_host_tests.cpp` and the 11 compile-fail files) and the 13 shared cases of `fixtures/hostile/cases.txt` replayed by every loader.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | a field after a repeat at the top level | covered | AC-1 of AZ-4210..AZ-4219; case R1 `construct_repeat_then_field`; the package tests above | scenarios.md |
| S2 | the field after a `when`, `flags`, group, nested row holding the repeat | covered | AC-1; cases R2, R3, R4; every package's follower tests (15 to 20 places) | scenarios.md |
| S3 | a second repeat follows a repeat | covered | AC-1; case R5; Java names the first repeat (fix round) | scenarios.md |
| S4 | two `when`s that cannot both be taken | covered | AC-1; case R6 | scenarios.md |
| S5 | a repeat inside a list or dict element | covered | AC-1; cases R7, R8 (Rust and bound C++ lists named not writable; C++ runs the unbound form) | scenarios.md |
| S6 | a repeat inside a `repeat` or `times` round | covered | AC-1; case R9 (direct form) in all nine: TypeScript, C#, Python, Go, Swift, Rust by the nesting rule, Java, C++ and Dart (nested row) by the new rule; the nested-row form is the gap D1 | scenarios.md |
| S7 | the repeat is the last thing read | covered | AC-2; cases K1 to K3 and K5 in each package's tests, same bytes | scenarios.md |
| S8 | a field after the repeat cannot write a byte | covered | AC-2 and the "cannot write a byte" tests of every package | scenarios.md |
| S9 | a `times` is followed by fields or sits in an element | covered | case K4 `pack_times_then_field` in nine loaders; Java, Go, C#, Swift pack-cap tests with `times` | scenarios.md |
| S10 | existing packets, fixtures, golden vectors, ring handoffs | covered | AC-4; no fixture, golden vector or ring driver scheme refused (TypeScript rule count 0 over 77,277 schemes; the other packages by logging copies); the step 11 run proves the bytes | scenarios.md |
| S11 | a package's own test or README example uses a refused scheme | covered | AC-4; 4 + 1 + 3 + 17 + 5 + 4 + 1 + 5 + 0 schemes rewritten or turned into refusal tests; README code blocks: 0 changed (98 compared) | scenarios.md |
| S12 | the check runs on a device | covered | AZ-4218 AC-5: four Rust pins +104 to +112 B flash, stack 0; AZ-4219 AC-6: C++ pins unchanged; `_docs/AGENT_GOTCHAS.md` | scenarios.md |
| D1 | a `repeat` inside a nested row or group that itself sits inside a round | gap-clear | quote: contract rule 3 "The repeat sits inside a `repeat` or `times` round. The next round follows it." and the contract 1.0.2 change log (Dart and C++ built it and read back other values with no error). Given a scheme `k, times(k){ group m { repeat(v) } }` or `repeat{ group m { repeat(v) } }`, When it is built in any of the nine packages, Then it is refused (`scheme_error`; `SchemeInvalid` in C++ and heap-free Rust). Today only Dart and C++ pin it (own tests); TypeScript, C#, Python, Go, Swift, Rust and Java were checked by an uncommitted probe, so no shared case stops a regression in them | batch 02 discoveries (Dart worker, C++ worker, nested-row probe) |
| D2 | the pass over the table is paid per call in the Rust heap-free API | covered | contract 1.0.2 Invariants and README (cost wording), `_docs/AGENT_GOTCHAS.md`; AZ-4218 AC-5 | review C1 |
| D3 | a scheme that breaks two parts of the rule at once | covered | fix round: all packages answer with the first violation in document order; one test each in TypeScript, Python, Dart, Swift; Java, C#, Go pin the element text | review B4, A-F3 |
| D4 | Java and C++ refuse a repeat inside a round (agent default) | covered | contract Decisions; `_docs/OPERATOR_TODO.md` D1 and D7 (applied, owner can overrule); AZ-4214 AC-5, AZ-4219 AC-5 | scenarios.md Fit card 3 |
| D5 | a second repeat or `times` whose body writes nothing after a repeat | covered | contract table (does not count); tests in TypeScript, Python, Dart, Java, C#, C++ (`repeat(v), repeat(bytes 0)` builds) | batch discoveries |
| D6 | C# never sets the bit of a `flags` that is a direct member of a `flags` | out-of-scope | not a repeat rule (found in review B outside the diff); queue item `csharp-flags-in-flags-presence` | review B |
| D7 | Dart had no load-aware timing helper | covered | `dart/test/support/timing.dart` (fix round) and `_docs/AGENT_GOTCHAS.md`; the remaining fixed-bound test is queue item `dart-colliding-keys-timing-helper` | Dart worker |
| D8 | the ESP stage installs the newest unpinned Arduino-ESP32 core | out-of-scope | not part of this feature; queue item `esp-core-arduino-pin` | C++ worker |
| D9 | R7 and R8 have no spelling in Rust and in bound C++ lists | covered | AZ-4218 AC-1, AZ-4219 AC-5; both loaders print `skipped: <reason>`; README names the packages | scenarios.md |
| D10 | `times` inside a nested row of a round builds in Java, Dart and C++ and is refused in the other six | out-of-scope | contract Non-Goals: "`times` is not restricted"; each package's older nesting rule keeps its behaviour; README says which | review A-F1 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| D1 | Given the shared cases `construct_repeat_in_group_in_repeat_round` (`repeat(0){ group m { repeat(1){ u8 v } } }`) and `construct_repeat_in_group_in_times_round` (`u8 k, times(k){ group m { repeat(1){ u8 v } } }`) in `fixtures/hostile/cases.txt`, When each of the nine loaders builds them, Then each is a scheme error (`SchemeInvalid` at the id of the inner repeat in C++ and in the heap-free Rust API) with the text the package already gives, and the case count is 90 | "The repeat sits inside a `repeat` or `times` round. The next round follows it." (`_docs/02_document/contracts/library/repeat-last.md`, rule 3) | new AZ-4232 (epic AZ-4209) |

### Not walked

- A `repeat` inside a nested row inside a nested row inside a round, more than one level: the walkers recurse through every container in all nine packages and the reviewers' random trees (420,000 in Rust, 1.1 million in C++, 200,000 in TypeScript, 300,000 in Dart) cover it; no shared case.
- Archangel's schemes: checked by the agent on 2026-11-12 (nine `Field.Repeat` schemes, all last); `_docs/OPERATOR_TODO.md` N3 is closed.

### Harness gaps

- `scripts/loop-tests.sh` writes a stage's stamp only on a tree that is clean apart from the state file (queue item `loop-tests-stamp-on-dirty-docs`).

## Round 2

**Date**: 2026-11-12
**Implement pass**: AZ-4232 (commit `888a3e8`), batch report `_docs/03_implementation/batch_02_loop113_report.md`
**Verdict**: COMPLETE — 19 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

D1 is covered now: AC-1 of AZ-4232 (`fixtures/hostile/cases.txt` holds `construct_repeat_in_group_in_repeat_round` and `construct_repeat_in_group_in_times_round`, 90 cases, `check-cases.sh` and `cases.test.sh` pass); AC-2 of AZ-4232 (each of the nine loaders builds both by hand and compares the whole text or the status and id: TypeScript `hostile-cases.ts`, C# `HostileVectorTests.cs`, Python `repeat_last_support.py`, Java `HostileLoop113.java` and `HostileRefusals.java`, Go `hostile_schemes_test.go`, Swift `HostileSchemes.swift`, Dart `hostile_constructs.dart`, Rust `hostile_tests/schemes.rs` and `refusals.rs` and `nostd_hostile_tests.rs`, C++ `hostile_repeat_last.hpp`); the production code path is the scheme check of each package listed above. No new candidate surfaced in round 2 (the discoveries of the extension workers are the anchor numbers of the README sketch, corrected in `fixtures/hostile/README.md`, and a second Dart construct loader with a hard-coded count, updated).

Open questions recorded for the owner, not gaps of this feature (batch report discoveries 10 to 12): a limit for scheme depth (Dart overflows the stack at 5,000 nested `when`s); whether a zero-width `times` body should be refused at build; the load scaling of the Java `AC-8` bound.
