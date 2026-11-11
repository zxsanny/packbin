---
loop: 99
branch: dev
---

# Dart in the language-pair, ECC and frame rings

**Task**: AZ-4146_dart_ring
**Name**: Dart in the language-pair, ECC and frame rings
**Description**: A Dart handoff driver and Dart in every ring both ways.
**Complexity**: 5 points
**Dependencies**: AZ-4138_dart_collections, AZ-4140_dart_ecc, AZ-4142_dart_frame, AZ-4145_dart_ci_suite
**Component**: dart
**Tracker**: AZ-4146
**Epic**: AZ-4133

## Problem

The rings prove that bytes written by one language are read by every other. Dart must be a member of each ring in both directions, and the ring's self-tests must catch a Dart driver that lies.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Dart hands off with every member of every kind, both ways, with 0 failures.
- Dart is in the ECC ring and the frame ring.
- The position driver prints the golden hex.

## Scope

### Included

- `.github/workflows/drivers/handoff-dart/`: a Dart program with a path dependency on `dart/`, handling `pack-<kind>`, `unpack-<kind>`, `unpack-<kind>-short`, the text kinds, `ecc-batch <file>`, `frame-batch <file>` (answering `open-skip` and `verify-skip` with `skip`, refusing malformed lines), and a `position` program.
- `ring-dart.sh` (build the driver to a compiled executable with the local `dart` or in the pinned image; stamp file; `--version`), `ring-lib.sh` (`run_lang dart`), `language-pair.sh` (Dart lines for every kind, the short refusals, the position list), `ring-ecc.sh` and `ring-frame.sh` language lists, `ring-frame-drivers.test.sh`, `ring-prepare.sh`, `ring-toolchains.sh` (`RING_DART`), the ring self-tests (a fake Dart liar in the ECC and frame ring tests), the wiring tests for the Dart rows.
- `publish-position.sh`: a `dart` case. `test.yml` ring job: `RING_DART`, the driver build and its cache. `scripts/frame/readme-examples.sh` language map entry (points at the test AZ-4148 writes).
- Owns: `.github/workflows/drivers/handoff-dart/**`, `ring-dart.sh`, `language-pair.sh`, `ring-*.sh`, `ring-*.test.sh`, `ring-wiring*`, `publish-position.sh`, `publish-position.test.sh`, the ring job of `test.yml`.

### Excluded

- Publish scripts other than `publish-position.sh` (AZ-4147)

## Acceptance Criteria

**AC-1: Language-pair ring (DT-7, S1)**
Given every kind of `language-pair.sh` and its ring members
When Dart packs and each member unpacks, and each member packs and Dart unpacks
Then the ring's hex and rows; failed handoffs 0

**AC-2: Short refusals (DT-7)**
Given the `-short` kinds
When Dart unpacks the short payload
Then a refusal with no row

**AC-3: ECC and frame rings (DT-7)**
Given `fixtures/ecc/ring-cases.txt` and `fixtures/frame/ring-cases.txt`
When `ring-ecc.sh` and `ring-frame.sh` run with Dart in the list
Then Dart's answers equal the other eight for every row

**AC-4: Liars are caught (DT-7)**
Given a fake Dart driver that answers one ECC row and one frame row wrongly
When the ring self-tests run
Then each ring fails and names Dart

**AC-5: Position (DT-7)**
Given `publish-position.sh dart`
When run
Then prints `4001000065cd1d00a3e1110100`

**AC-6: Wiring**
Given the ring wiring tests
When run
Then `RING_DART` equals the tool pin and the compose image; the Dart cache key hashes the driver's and the package's `pubspec.yaml`

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Language-pair ring: every kind of `language-pair.sh` and its ring members | the ring's hex and rows; failed handoffs 0 |
| AC-2 | Short refusals: the `-short` kinds | a refusal with no row |
| AC-3 | ECC and frame rings: `fixtures/ecc/ring-cases.txt` and `fixtures/frame/ring-cases.txt` | Dart's answers equal the other eight for every row |
| AC-4 | Liars are caught: a fake Dart driver that answers one ECC row and one frame row wrongly | each ring fails and names Dart |
| AC-5 | Position: `publish-position.sh dart` | prints `4001000065cd1d00a3e1110100` |
| AC-6 | Wiring: the ring wiring tests | `RING_DART` equals the tool pin and the compose image; the Dart cache key hashes the driver's and the package's `pubspec.yaml` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Fit decision 3: every kind, both ways, with every member; no kind is left out for Dart.
- The driver uses only the public API of the package.
- No file over 500 lines: the driver is split by kind group as the Swift and Go drivers are.

## Risks & Mitigation

**Risk 1: Ring wall time**
- *Risk*: A ninth member adds handoffs to the longest CI job (the ring was the wall before).
- *Mitigation*: The driver is a compiled executable built once; timings are read after the first CI run and recorded.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
