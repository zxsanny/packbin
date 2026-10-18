---
loop: 35
branch: dev
---

# Compact text: reference encoder, decoder and vectors file

**Task**: AZ-2647_compact_text_vectors
**Name**: Compact text: reference encoder, decoder and vectors file
**Description**: A reference codec outside the packages that writes the vectors file every package loads, and a check that proves the file.
**Complexity**: 3 points
**Dependencies**: AZ-2646
**Component**: compact-text (fixtures)
**Tracker**: AZ-2647
**Epic**: AZ-2645

## Problem

Eight packages must agree on the bytes. Each needs the same list of strings, expected bytes and expected refusals, produced by one independent reference, not by one of the packages.

## Outcome

- `fixtures/text/vectors.txt`: one row per case, readable by a small loader in every language.
- A reference encoder and decoder written from the contract, and a check script.

## Scope

### Included
- `scripts/text/reference.py` (encode, decode, refusals) that reads only `tables.json` and the contract rules.
- `fixtures/text/vectors.txt` with at least 300 rows: `enc` rows (string as escaped UTF-8 hex, expected bytes hex) from the corpus (Ukrainian, Russian, English, mixed, numbers), the 9 rows of `input_data/expected_results/results_report.md`, boundaries (empty, 127 and 128 payload bytes, 65,535 UTF-8 bytes), every control symbol, every mode switch, LOCK runs, ESC for BMP and non-BMP code points, and the raw fallback; `ref` rows (a complete packet from the `user` and `nested` ring schemes, with every string in it); `bad` rows (payload hex, the refusal kind) for the decoder refusals of the contract; `flip` rows (a vector and a bit index) used by the damage test.
- `fixtures/text/check-vectors.sh` and `check-vectors.test.sh`: the check re-derives every row and fails on a corrupted copy (the repository's mutant pattern).

### Excluded
- Any package code; the hostile `cases.txt` (AZ-2657).

## Acceptance Criteria

**AC-1: Rows are derived, not typed**
Given the contract and `tables.json`
When `check-vectors.sh` re-runs the reference over every `enc` row
Then every expected byte string equals the reference output; mismatches 0

**AC-2: Reference round trip**
Given all `enc` rows and 100,000 random Unicode strings
When encode then decode with the reference
Then the string is unchanged; mismatches 0 (CS-5)

**AC-3: Refusals**
Given every `bad` row
When the reference decoder runs
Then each is refused with the listed kind and no value (CS-9, CS-16)

**AC-4: Coverage**
Given the vectors file
When the check counts rows by kind
Then at least 300 `enc`, 4 `ref`, 20 `bad`, 20 `flip`; every control symbol and mode switch appears in an `enc` row

**AC-5: The check fails on a bad file**
Given a copy of the file with one byte changed, one row removed, one kind misspelled
When `check-vectors.test.sh` runs the check on each copy
Then the check exits non-zero for every copy

## Non-Functional Requirements

**Performance**
- The check runs in at most 20 seconds in the scaffold job.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | derivation | reference output equals file |
| AC-2 | fuzz | 100,000 strings round trip |
| AC-3 | bad rows | refusal kinds |
| AC-5 | mutants | three corrupted copies fail |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | vectors file | check-vectors.sh | exit 0 | — |
| AC-5 | corrupted copies | check-vectors.test.sh | exit 0 (all mutants caught) | — |

## Constraints

- The wire format is the one in `_docs/02_document/contracts/library/compact-text.md` (AZ-2646). A language never invents a choice the contract fixes (tie-breaks, table order, pad bits).
- The encoder works on the UTF-8 bytes this package already produces for a string today, so lone-surrogate and invalid-input behavior of the language does not change (fit decision, feature-description).
- Positions: a string field, a list element, a dictionary key, a dictionary value that is a list of strings, a string under `repeat`, `times` or `flags` (scenario S12). Dictionary pairs are still sorted by the key's UTF-8 bytes before the keys are encoded; a repeated decoded key is refused (S10).


## Contract

Consumer of `compact-text.md`; producer of the file format `fixtures/text/vectors.txt`, documented in `fixtures/text/README.md`.


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire break: packets with strings written before this loop cannot be read | Owner accepted 2026-10-18 (no tag was ever published) | accepted-risk | Medium |
