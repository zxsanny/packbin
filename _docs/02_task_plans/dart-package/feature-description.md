# Feature: Dart package (AZ-4133, loop 99)

A ninth language package, `dart/` (pub package and library `packbin`), hand-written in Dart (ADR-001: no shared walker, no generator, no wrapper of the C++ core). It packs and unpacks the same bytes as the eight packages for every feature they share today (wire format, schemes and dispatch, compact text, lists and dictionaries, limits, hostile vectors, message error correction by count and percentage, frame mode). Rows are typed objects bound by getter and setter closures, or maps. Unpack returns a result with an error value and never throws on input; pack and scheme construction throw a typed error. Pure Dart: no runtime dependency, no `dart:mirrors`, no FFI, native targets only, Dart 3.13 and newer. Dart joins the CI suite, the three rings (language-pair, ECC, frame) both ways, the golden gate of the publish, and gets a pub.dev target in the release run. Problem, decisions D-1 to D-5, defaults A-1 to A-7, ACs DT-1 to DT-20: `problem.md`, `acceptance_criteria.md` in this folder.

## Scenarios

See `scenarios.md` (S1 to S13; S13 out of scope; AC refs DT-1 to DT-20).

## Complexity (New Task Step 2)

13 points or more (Scope high: a new package plus shared CI, three rings, publish gate, README, hostile checker; Novelty medium: a new toolchain in CI, pub.dev's OIDC publishing, 64-bit `int` that wraps; Risk high). Routing: mandatory `/decompose --feature`. Size reference: Swift, 12 tasks and 47 points, before compact text, error correction and frame mode existed. Lessons applied (`_docs/LESSONS.md`, 2026-11-01): the rule for a zero or off value is stated in each spec; every reader of a shared fixture is checked before a file changes; file lines are counted at the batch gate (500-line cap).

## Codebase analysis (Step 4, reads only)

- Insertion points: new `dart/`; `.github/workflows/` (`run-suite.sh dart`, `test.yml` suites, ring, scaffold and publish-gate jobs, `language-pair.sh`, `ring-lib.sh`, a `ring-dart.sh` and `drivers/handoff-dart/`, `ring-ecc.sh`, `ring-frame.sh`, `ring-prepare.sh`, `ring-toolchains.sh`, the ring and wiring tests, `publish-lib.sh` language and target lists, `publish-position.sh`, `publish-build.sh`, `publish-inside.sh`, `publish-check.py`, `publish-upload.sh`, `publish-query.sh`, `publish-registries.sh`, `publish-jobs-layout.py`, `tool-pins.txt`); `docker-compose.test.yml`, `docker-compose.publish.yml`; `scripts/loop-tests.sh`, `scripts/text/emit_tables.py`, `scripts/text/check-emitted.sh`, `scripts/frame/readme-examples.sh`; `fixtures/hostile/check-cases.sh`, `cases.test.sh` and the `Run by` lines of `fixtures/hostile/README.md`; `fixtures/*/README.md`; `README.md`.
- Contracts and layout: the three contracts under `contracts/library/` get a Dart consumer and spelling line; `module-layout.md` gets a `Component: dart` block and the packages table row; `components/09_dart_package/`; ADR-011 (Dart publishes to pub.dev from the version tag), aligned with ADR-001 (own walker) and ADR-002 (publish from a version tag). No ADR conflict.
- Reference: the TypeScript package and tests for behavior row by row; the Swift package (32 source files, 5,546 lines; 95 test files, 13,105 lines) for the file split and the test list; the Go driver (`drivers/handoff-go/`, about 700 lines) for the ring driver.
- No version-equality script exists: each artifact takes its version from the tag at build time and `publish-check.py` checks it.
- Seams (Step 4.6): Dart ↔ language-pair ring (every kind, both ways), Dart ↔ ECC ring and frame ring (`ecc-batch`, `frame-batch`), Dart ↔ golden gate (all-or-nothing), Dart ↔ hostile checker (nine names, whole-word match), Dart ↔ text tables emitter (generated file equals `tables.json`), Dart ↔ pub.dev (version from the tag; already-published version). `interaction-risks.md` is updated by the owning tasks.

## Fit decisions

| card | collision | chosen option |
|------|-----------|---------------|
| 1 | The release ADRs name six registries, a Go tag and a Swift check; pub.dev takes CI uploads only through GitHub OIDC from a tag-triggered run | A — ADR-011; a `pubdev` required target; first version by the owner by hand |
| 2 | The golden gate is all-or-nothing | A — Dart joins the gate |
| 3 | Ring kinds run in different language subsets | A — Dart joins each kind's ring both ways with every member |
| 4 | Where the eight differ, which does Dart copy | A — TypeScript at HEAD with Go-1 to Go-4 as Swift took them |
| 5 | `check-cases.sh` counts eight names | A — checker, `Run by` lines and the Dart loader in one task |
| 6 | `test.yml` is at 20 jobs | A — Dart shares the Go suites job and an existing publish-gate group |
| 7 | Unpack error style | A — a result with an error value; pack and construction throw |

## Assumptions (new-task Step 5, auto-applied 2026-11-10)

A-1 to A-7 of `problem.md`, plus:

1. `components/09_dart_package` and a `module-layout.md` Dart block are written by the docs task.
2. One worker writes the walker files in `dart/` at a time; the standalone modules (text codec, crypto, frame, error-correction codec) and the shared CI, ring and publish files go to separate workers with disjoint file sets. The parent owns tracker, commits and the single total review and test run.
3. No tag is pushed and nothing is uploaded in loop 99; DT-10 is proven by the publish tests and `dart pub publish --dry-run`.
4. Jira: epic AZ-4133; tasks AZ-4134 to AZ-4148.
