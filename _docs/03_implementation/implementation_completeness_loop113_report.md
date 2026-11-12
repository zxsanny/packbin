# Implementation completeness — loop 113 (epic AZ-4209, feature `repeat-must-be-last`)

Date: 2026-11-12. Inputs: the eleven specs in `_docs/02_tasks/done/` (AZ-4210 to AZ-4219, AZ-4232), the contract `repeat-last.md` 1.0.2, the code at `888a3e8`, `batch_01_loop113_report.md`, `batch_02_loop113_report.md`, the review `reviews/batch_01_loop113_review.md`, the assessment `_docs/loops/loop113/assessment113.md`.

Scaffold grep over the added lines of the library source (`placeholder`, `stub`, `TODO`, `FIXME`, `fake`, `mock`, `native bridge`, `not implemented`): 0 hits. Every check is a real walk of the scheme in the package that builds it; no passthrough and no shared generated scheme (ADR-001).

| Task | Description / Outcome vs code | Scope | AC | NFR | Verdict |
|------|-------------------------------|-------|----|-----|---------|
| AZ-4210 | cases R1 to R9 and K1 to K4 in `cases.txt`, README rule and upgrade note, contract lines | all included files changed; the 75 older lines untouched | AC-1 to AC-5 tested (`check-cases.sh`, `cases.test.sh`) | compatibility: no existing case changed | PASS |
| AZ-4211 TypeScript | `validateRepeatLast` refuses at build, texts of the contract | check, loader, own tests; probe and rule-count tool | AC-1 to AC-6 | one walk at build, nothing per pack or unpack; 16,000 siblings 4 ms | PASS |
| AZ-4212 C# | `RoundScopes.CheckLast` | as above, typed rows and the dictionary form | AC-1 to AC-5 | one walk | PASS |
| AZ-4213 Python | `_validate_repeat_last` | as above | AC-1 to AC-5 | one forward pass | PASS |
| AZ-4214 Java | `SchemeOrder.repeatLast`; repeat in a round refused; pack-time refusal removed | as above plus the removal of the dead inner-repeat code | AC-1 to AC-6 (AC-2 is the agent default, owner D1 and D7 applied) | one walk | PASS |
| AZ-4215 Go | `checkRepeatLast` | as above | AC-1 to AC-5 | one forward walk | PASS |
| AZ-4216 Swift | `checkRepeatLast` | as above, README snippet test | AC-1 to AC-5 | one forward walk, 8,000 siblings 13 to 20 ms | PASS |
| AZ-4217 Dart | `checkRepeatLast`; nested row of a round refused; CHANGELOG | as above plus `test/support/timing.dart` | AC-1 to AC-5 | one pass, 16,000 siblings 28 to 35 ms | PASS |
| AZ-4218 Rust | `check_repeat_last` (map form), `repeat_last` in `nostd::validate` | as above, device pins | AC-1 to AC-7 | map form: at build; heap-free API: one linear pass per pack and unpack (the spec's "nothing per pack or unpack" holds for the map form only; contract 1.0.2 and README say so); pins +104 to +112 B, stack 0, inside the 256 B / 64 B budget | PASS |
| AZ-4219 C++ | `detail::check_repeat_last`; constexpr compile errors; unbound list and dict; repeat in a round and a group of a round | as above, 11 compile-fail files | AC-1 to AC-8 | stored once in `status`; device pins unchanged | PASS |
| AZ-4232 | two shared cases (repeat in a group of a round), nine loaders | cases, README sections, loaders | AC-1 to AC-3 | compatibility | PASS |

## System pipeline audit

| Pipeline | Production callers, seam to seam | Verdict |
|----------|----------------------------------|---------|
| A scheme author builds a scheme (public constructor of each package) to the check | TypeScript `new Scheme` and `scheme()`, C# `Scheme` constructor, Python `Scheme.__init__`, Java `Scheme` constructor, Go `NewScheme`, Swift `Scheme.init`, Dart `scheme()` and `rowScheme()`, Rust `MapScheme::new` and `nostd::validate`, C++ `scheme<Row>()` and `check_table` for run-time and `constexpr` schemes: the reviewers confirmed each is the only construction path (the second C# and Swift constructors delegate; Rust has no other `MapScheme` constructor) | WIRED |
| The shared hostile cases to the nine loaders to the packages' own scheme check | `fixtures/hostile/cases.txt` (90 cases) read by every loader; each unknown id fails loudly; step 11 ran all nine | WIRED |
| Unpack of wire bytes | unchanged; Java's removed code was reachable only by a scheme that no longer builds (security audit area 1) | WIRED (no change) |

All eleven tasks PASS; the one pipeline of the feature is WIRED. No BLOCKED item and no remediation task.
