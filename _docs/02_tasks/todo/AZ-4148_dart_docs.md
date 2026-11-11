---
loop: 99
branch: dev
---

# Dart: README section, runnable examples and the nine-language docs

**Task**: AZ-4148_dart_docs
**Name**: Dart: README section, runnable examples and the nine-language docs
**Description**: The README Dart section with examples run as tests, the pub.dev files, and the documents that list the languages.
**Complexity**: 3 points
**Dependencies**: AZ-4144_dart_parity_rows, AZ-4147_dart_release
**Component**: dart
**Tracker**: AZ-4148
**Epic**: AZ-4133

## Problem

A user finds the package through the README and pub.dev. Every example shown must run, and every document that lists the packages must name nine.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- The README has a Dart section whose examples run in CI and print the README hex.
- `dart/README.md`, `dart/CHANGELOG.md` and `dart/example/` exist for pub.dev.
- The documents that list the packages name Dart.

## Scope

### Included

- `README.md`: Supported languages row, a Dart section (install, pack and unpack example, rows, errors, limits), the ECC table rows (count and percentage), the frame mode example and spelling, the data-type spelling line, the Untrusted input notes that name languages, "nine packages" where nine is meant.
- Dart tests that compile and run every Dart example of the README (the package examples and the frame example), reading the README file so a README edit that breaks an example fails.
- `dart/README.md` (short, pointing at the repository README), `dart/CHANGELOG.md`, `dart/example/packbin_example.dart`, doc comments on the public names.
- `_docs/02_document/`: `architecture.md`, `module-layout.md` (`Component: dart` block and table row), `components/09_dart_package/description.md` and `tests.md`, `glossary.md`, the three contracts (consumer and spelling lines; no version bump: no wire or behavior change), `system-flows.md`, `epics.md`, `interaction-risks.md` (the Dart seams), the tests docs that list languages (`environment.md`, `test-data.md`, `traceability-matrix.md` Dart rows).
- `fixtures/crypto/README.md`, `fixtures/ecc/README.md`, `fixtures/text/README.md`, `fixtures/frame/README.md`, `fixtures/hostile/fuzz/README.md`.
- Owns: `README.md`, `dart/README.md`, `dart/CHANGELOG.md`, `dart/example/**`, `dart/test/readme*`, `_docs/02_document/**` except `adr/`, the fixture READMEs named above.

### Excluded

- ADR-011 and `_docs/04_deploy/packages.md` (AZ-4147)
- `fixtures/hostile/README.md` (AZ-4143)

## Acceptance Criteria

**AC-1: README examples run (DT-13)**
Given every Dart code block of `README.md`
When the README example tests run
Then each compiles, runs and prints the hex the README shows; mismatched bytes 0; a README block with a changed hex fails the test

**AC-2: pub.dev files (DT-13)**
Given `dart/README.md`, `dart/CHANGELOG.md`, `dart/example/`
When `dart pub publish --dry-run` runs
Then 0 warnings about a missing README, changelog, example or description; `dart analyze` passes on the example

**AC-3: Nine names (DT-20)**
Given the documents listed in Scope
When searched for "eight packages", "all eight" and the language lists
Then places that say eight where nine is meant: 0; each language list names Dart

**AC-4: Frame example script**
Given `scripts/frame/readme-examples.sh`
When run
Then the Dart frame example test is found and passes

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | README examples run: every Dart code block of `README.md` | each compiles, runs and prints the hex the README shows; mismatched bytes 0; a README block with a changed hex fails the test |
| AC-2 | pub.dev files: `dart/README.md`, `dart/CHANGELOG.md`, `dart/example/` | 0 warnings about a missing README, changelog, example or description; `dart analyze` passes on the example |
| AC-3 | Nine names: the documents listed in Scope | places that say eight where nine is meant: 0; each language list names Dart |
| AC-4 | Frame example script: `scripts/frame/readme-examples.sh` | the Dart frame example test is found and passes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Docs describe what the code does at HEAD; a claim about a version Dart was not tested on is not written.
- The contracts keep their version numbers (a new consumer is not a contract change); the consumer lists gain Dart.
- No source file over 500 lines; `README.md` is exempt as it is today.

## Risks & Mitigation

**Risk 1: README drift**
- *Risk*: An example is edited later and no longer matches the test.
- *Mitigation*: The tests read the code blocks from `README.md` itself.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
