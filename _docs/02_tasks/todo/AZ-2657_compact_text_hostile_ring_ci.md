---
loop: 35
branch: dev
---

# Hostile cases, ring vectors and CI wiring for compact text

**Task**: AZ-2657_compact_text_hostile_ring_ci
**Name**: Hostile cases, ring vectors and CI wiring for compact text
**Description**: The shared hostile cases, the cross-language ring and the CI checks carry the new string format.
**Complexity**: 3 points
**Dependencies**: AZ-2648, AZ-2649, AZ-2650, AZ-2651, AZ-2652, AZ-2653, AZ-2654, AZ-2655, AZ-2656
**Component**: fixtures / CI
**Tracker**: AZ-2657
**Epic**: AZ-2645

## Problem

The hostile cases hold two string rows in the old format, the ring compares the `user` and `nested` packets in the old bytes, and nothing yet checks the vectors file in CI or reports the size gain.

## Outcome

- Every package passes the same hostile string rows; the ring passes with the new bytes; CI proves the vectors file and reports the sizes.

## Scope

### Included
- `fixtures/hostile/cases.txt` (67 rows today): `invalid_utf8` and `invalid_utf8_dict_key` rewritten in the new format (an invalid raw payload `01 03 10 c3 28`; a dictionary key `01 01 00 02 10 ff 00`); their expected kinds stay `bad_value|short_packet`; the other refusals (a cut code, non-zero pad bits, bad start mode, CAP rules, ESC cut or invalid, a count over the packet, varint) are the `bad` rows of `fixtures/text/vectors.txt`, run by every package task, so no new case id (and no new loader line in the eight packages) is added; `fixtures/hostile/README.md` wire-rules line and case sections; `fixtures/hostile/fuzz/corpus.txt` and its README; all 8 loaders pass (C# `HostileVectorTests.cs`:411, TS `hostile.test.ts`:60, Python `test_hostile_vectors.py`, Rust `hostile_tests.rs`, Java `HostileVectorTest.java`, Go `hostile_loader_test.go`, Swift `HostilePacks.swift`, C++ `hostile_host_tests.cpp`).
- `.github/workflows/language-pair.sh` (`user_hex` line 11, `nested_hex` line 12) with the `ref` bytes; the 8 ring drivers in `.github/workflows/drivers/`.
- `check-vectors.sh` and its mutant test in the `scaffold` job beside `check-cases.sh` (the job count of `test.yml` stays at 20 or fewer); `scripts/loop-tests.sh` runs them.
- `scripts/text/size_report.py`: sizes against UTF-8 + 2 on the corpus recipe, written to `_docs/02_task_plans/compact-strings/size_report.md`.

### Excluded
- Per-package string tests (their tasks); README (AZ-2658).

## Acceptance Criteria

**AC-1: Hostile rows pass everywhere**
Given the updated `cases.txt`
When each of the 8 loaders runs it
Then every row gives its expected outcome kind in every package, including the C++ refusals (CS-9, CS-16)

**AC-2: Ring passes**
Given the new `user_hex` and `nested_hex`
When `language-pair.sh` hands each packet from every language to every other
Then every language pair matches (CS-7)

**AC-3: Vectors are checked in CI**
Given the scaffold job
When it runs `check-vectors.sh` and the mutant test
Then both pass, and a corrupted vectors file turns the job red (CS-7)

**AC-4: Job budget**
Given `test.yml`
When the job list is counted
Then at most 20 jobs and no job waits for a runner slot

**AC-5: Size report**
Given the corpus recipe and the held-out sentences
When `size_report.py` runs
Then CS-1, CS-2, CS-14 and CS-13 hold and the report is saved with the date and the recipe hashes

## Non-Functional Requirements

**Performance**
- The scaffold job grows by at most 20 seconds; the test.yml wall (217 s median) grows by at most 10 s.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each package's hostile loader | string rows pass |
| AC-3 | mutants | corrupted vectors file fails |
| AC-5 | report checks | bounds asserted |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | all 8 drivers | `language-pair.sh` full ring | every language pair matches | CS-7 |
| AC-4 | CI workflow | count jobs and look at start times | ≤ 20 jobs | — |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

Consumer of `compact-text.md`, `vectors.txt`.


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
