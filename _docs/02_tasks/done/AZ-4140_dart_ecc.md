---
loop: 99
branch: dev
---

# Dart: message error correction (parity count and percentage)

**Task**: AZ-4140_dart_ecc
**Name**: Dart: message error correction (parity count and percentage)
**Description**: Parity bytes per scheme, unpack with repair and the percentage form, on the shared vectors.
**Complexity**: 5 points
**Dependencies**: AZ-4136_dart_rounds
**Component**: dart
**Tracker**: AZ-4140
**Epic**: AZ-4133

## Problem

Over a noisy link a message can arrive with flipped bytes. The other packages add parity bytes per scheme and repair on unpack (ADR-007), by count or by percentage (ADR-010). Dart must write and repair the same bytes.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Every row of `fixtures/ecc/vectors.txt` and `percent-vectors.txt` passes in Dart.
- Unpack with a repair limit returns the repaired count; damage past the limit is `uncorrectable`.

## Scope

### Included

- The codec over GF(256), polynomial 0x11D, as `message-ecc.md` 1.1.0 states: encode and repair, under `dart/lib/src/ecc*`.
- The scheme's parity setting by count (0 to 32) and by percentage (0 to 100; `n = min(32, ceil(p * L / 100))`), the repair limit `t` (0 to `n/2`; percentage limit 0 to 16), the 254-byte message bound, one parity setting per unpack call, the error kinds `uncorrectable` and `too_long`.
- Loaders and tests for both vector files.
- Owns: `dart/lib/src/ecc*`, `dart/test/ecc*`, and the parity setting on the scheme.

### Excluded

- The ECC ring (AZ-4146)

## Acceptance Criteria

**AC-1: Count vectors (DT-18)**
Given every row of `fixtures/ecc/vectors.txt` (`enc`, `fix`, `bad`, `lim`, `par`, `lmt`)
When run in Dart
Then the row's bytes, repaired count or refusal; mismatches 0

**AC-2: Repair (DT-18, S9)**
Given a packed message with parity 8, and copies with 1, 4 and 5 flipped bytes
When unpacked with limit 4, and with limit 0
Then 1 and 4 flips: the row and repaired 1 and 4; 5 flips: `uncorrectable`; with limit 0 every damaged copy is `uncorrectable` and the clean one unpacks with repaired 0

**AC-3: Percentage vectors (DT-18)**
Given every row of `fixtures/ecc/percent-vectors.txt` (`pct`, `encp`, `inv`, `limp`, `fixp`, `badp`, `parp`, `lmtp`)
When run in Dart
Then the row's parity count, bytes, repaired count or refusal; mismatches 0

**AC-4: Off values (zero value)**
Given parity 0 and percentage 0
When packed and unpacked
Then no parity bytes; the bytes equal the scheme without the setting; the 254-byte bound does not apply (as the contract states for the unprotected path)

**AC-5: Out of range**
Given parity 33 or -1, a limit above `n/2`, percentage 101, a mix of count and percentage, and a message of 255 bytes with parity
When set or packed
Then refused when set (a thrown error) for the first four; `too_long` for the 255-byte message

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Count vectors: every row of `fixtures/ecc/vectors.txt` (`enc`, `fix`, `bad`, `lim`, `par`, `lmt`) | the row's bytes, repaired count or refusal; mismatches 0 |
| AC-2 | Repair: a packed message with parity 8, and copies with 1, 4 and 5 flipped bytes | 1 and 4 flips: the row and repaired 1 and 4; 5 flips: `uncorrectable`; with limit 0 every damaged copy is `uncorrectable` and the clean one unpacks with repaired 0 |
| AC-3 | Percentage vectors: every row of `fixtures/ecc/percent-vectors.txt` (`pct`, `encp`, `inv`, `limp`, `fixp`, `badp`, `parp`, `lmtp`) | the row's parity count, bytes, repaired count or refusal; mismatches 0 |
| AC-4 | Off values: parity 0 and percentage 0 | no parity bytes; the bytes equal the scheme without the setting; the 254-byte bound does not apply (as the contract states for the unprotected path) |
| AC-5 | Out of range: parity 33 or -1, a limit above `n/2`, percentage 101, a mix of count and percentage, and a message of 255 bytes with parity | refused when set (a thrown error) for the first four; `too_long` for the 255-byte message |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- `message-ecc.md` 1.1.0 is the contract; this task changes no fixture.
- The repair works on a copy: the caller's buffer is not changed when repair fails.
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: Percentage rounding**
- *Risk*: `ceil(p * L / 100)` done in floating point rounds differently for some `p` and `L`.
- *Mitigation*: Integer arithmetic; the `pct` rows pin every case.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
