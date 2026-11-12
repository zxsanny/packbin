# Autodev loop record - loop 113

loop: 113
branch: dev
plan_artifact: _docs/loops/loop113/plan113.md
tasks_shipped: [AZ-4210, AZ-4211, AZ-4212, AZ-4213, AZ-4214, AZ-4215, AZ-4216, AZ-4217, AZ-4218, AZ-4219, AZ-4232]
decisions:
  - owner (2026-11-12, loop 112, carried): refuse a repeat that is not the last thing a packet reads, when the scheme is built, in all nine packages (contract `repeat-last.md`, now 1.0.2)
  - agent (applied, the owner can overrule them): Java and C++ also refuse a repeat inside a round (OPERATOR_TODO D1); the Java text of that refusal gives the reason of the rule and not the sentence of the other seven, which is false in Java (D7, contract 1.0.1); the device pins follow the measured figure inside 256 B of flash and 64 B of stack (Rust +104 to +112 B, C++ unchanged); a zero-width `times` after a repeat is left as it was (D8)
  - agent (assessment round 1, EXTEND): two shared hostile cases for a repeat inside a group of a round, because Dart and C++ had that hole (new task AZ-4232, Jira key AZ-4232)
measurements:
  - step 11 `scripts/loop-tests.sh --all` at `888a3e8` (17:19 to 17:44, 1,444 s, host load 9 to 111, the Mac kept awake): 15 passed, 0 failed, 0 skipped; typescript 40 s, csharp 98, python 105, java 21, rust 120, go 233, cpp 85, dart 86, swift 477, scaffold 460, cpp-embedded-arm 19, rust-embedded 65, ring 159, ac10 6, publish-gate 484 (8 shares, wall 483 s, sum 3,059 s, tree the same before and after); NOT RUN: the vcpkg supports and consumer checks (no vcpkg tool); the ESP core stage ran in the C++ worker (`run.sh host esp core`, 0 targets failed, 525 s)
  - suites at their last runs: TypeScript 3,700 tests; C# 5,474 on `net10.0` and `netstandard2.0`; Python 5,128; Java `PackbinTest checks: 70945`, 12 mains, api-check PASS; Go 399 under `-race`; Swift 467 tests in 82 suites; Dart +2,088; Rust 1,931; C++ clang and `gcc:16` green, 11 compile-fail files; shared hostile cases 90 (75 before)
  - device: Rust heap-free pins +112 B (base), +104 B (text), +104 B (ecc), +112 B (frame) of flash, stack unchanged; C++ pins unchanged
  - diff outside `_docs/`: 121 files, +7,763 -329 (library source 27 files, 1,012 lines; tests and loaders 86 files, 6,858 lines); `structure_2026-11-12_loop113.md`
  - probes: 85 lines, 75 refused, 10 controls built and read back; the TypeScript rule count is 0 (was 4)
  - smoke: 8/8 (`smoke113.md`)
review: "PASS_WITH_WARNINGS after fixes (`_docs/03_implementation/reviews/batch_01_loop113_review.md`): first pass FAIL on 1 High (documents: Dart's nested row of a round), 1 Medium (Java dead code), 17 Low; three read-only reviewers, one read-only probe and the parent; all fixed in `3b548f3` except the accepted one named there"
feature_assessment: COMPLETE, round 2 (`assessment113.md`); round 1 was EXTEND (one gap-clear row, D1), implemented as AZ-4232
security: "full audit (lite T3 escalated): PASS_WITH_WARNINGS, 0 Critical, 0 High, 0 Medium, 2 Low (`_docs/05_security/security_report_loop113.md`, `lite_loop113.md`): F79 quadratic walk in Java, C# and Go on a deep chain (queued), F80 a pre-existing test-only overflow in `cpp/tests/core/ecc_api_tests.cpp` (queued)"
retro: "`_docs/06_metrics/retro_2026-11-12_loop113.md` (loops 109 to 113; next due by loop 118)"
leftovers:
  - _docs/02_tasks/backlog/csharp-flags-in-flags-presence.md
  - _docs/02_tasks/backlog/cpp-ecc-api-test-out-buffer.md
  - _docs/02_tasks/backlog/walk-first-writer-memo-java-csharp-go.md
  - _docs/02_tasks/backlog/dart-colliding-keys-timing-helper.md
  - _docs/02_tasks/backlog/dart-deep-when-chain-stack-overflow.md
  - _docs/02_tasks/backlog/esp-core-arduino-pin.md
  - _docs/02_tasks/backlog/element-row-sibling-probe.md
  - _docs/02_tasks/backlog/loop-tests-stamp-on-dirty-docs.md
  - _docs/02_tasks/backlog/csharp-dotnet-test-hang-without-console-logger.md
  - _docs/02_tasks/backlog/s390x-percentage-packets-vs-m3.md
  - _docs/02_tasks/backlog/embedded-arm-dns-cause.md (blocked on a failing run)
  - _docs/02_tasks/backlog/dart-readme-install-lines-after-first-publish.md (blocked on OPERATOR_TODO N1)
  - _docs/OPERATOR_TODO.md: N1 (first `dart pub publish`), N2 (vcpkg tool), N4 (autodev skill sentence); decisions D5 (pairing step), D6 (released tickets to Done), D8 (zero-width times), D9 (scheme depth) open or applied as written there; N3 closed (Archangel's nine schemes checked: all repeats last)
notes:
  - the next tag carries AZ-4205 and the whole epic; the README "If you upgrade" section says what stops building (a field after a repeat, a repeat in an element, in Java, C++ and Dart a repeat in a round)
  - Jira at close: AZ-4210 to AZ-4219, AZ-4232, AZ-4205, AZ-4206 In Testing (read back); AZ-4209 (epic) To Do until a release carries it; AZ-4198 and AZ-4199 In Testing (unchanged)
  - Jira returned AZ-4232 for the task created by the assessment (not the next number); the spec file is named after that key
  - not verified by the loop: the CI run of this push (read after it, in the chat); a physical board; the Go walk of the security audit at run time (the Go suite ran in step 11)
smoke: PASS (agent run, owner rule 2026-10-12: 8/8 steps passed at 888a3e8; checks in smoke113.md)
smoke_artifact: _docs/loops/loop113/smoke113.md
assessment_artifact: _docs/loops/loop113/assessment113.md
loop_end_merge: main
