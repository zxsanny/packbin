---
loop: 97
branch: dev
---

# Parity percentage in the Java package

**Task**: AZ-3503_parity_percent_java
**Name**: Parity percentage in the Java package
**Description**: The Java package derives the parity count from the message length under a percentage.
**Complexity**: 3 points
**Dependencies**: AZ-3499_parity_percent_reference
**Component**: Java package
**Tracker**: AZ-3503
**Epic**: none

## Problem

The Java package can only declare a fixed parity count. The owner wants the count derived from the message length under a percentage, with the same bytes and rules in all eight languages.

## Outcome

- A Java scheme can declare a percentage; messages carry the derived count; unpack finds it from the received length alone.
- The package passes the new vector rows and every old test.

## Scope

### Included
- The Java scheme setting (a scheme method `withParityPercent(p)` and a read-only `parityPercent()`), pack, unpack, the repair limit rule and the dispatch rule, as the acceptance criteria say.
- The package's vector test reads the new rows; new tests for AC-1 to AC-7; the package's own suite and its timing checks stay green.
- The package's README spelling is proposed here and written by AZ-3509.

### Excluded
- The ring rows and drivers (AZ-3508), the README and component docs (AZ-3509), the contract and vectors (AZ-3499).
- A percentage chosen per message, link-quality feedback, any change to the fixed count, the code, the 254-byte limit or the cap of 32.

## Acceptance Criteria

Plan, wording and figures: `_docs/02_task_plans/parity-percent/acceptance_criteria.md` (AC numbers there are noted in brackets), `_docs/02_task_plans/parity-percent/input_data/expected_results/results_report.md` and `_docs/02_task_plans/parity-percent/scenarios.md`.

**AC-1: The setting**
Given a scheme in the Java package
When a percentage 0 to 100 is set with a scheme method `withParityPercent(p)` and a read-only `parityPercent()`
Then the scheme reports it; a percentage below 0 or above 100, or a percentage together with a fixed count above 0 declared in one constructor, is refused as `bad_parity` in the package's own invalid-scheme error naming the percentage and 100; setting a percentage on a scheme that has a count replaces the count (and the other way round); the other limit setters keep what the scheme has

**AC-2: Count and bytes**
Given percentages 0, 10, 25, 50 and 100 and clear messages of 0, 1, 3, 10, 40, 100 and 222 bytes
When each is packed
Then the parity count is `min(32, ceil(p x L / 100))` (the table of `results_report.md`), the sent bytes are the clear bytes then the parity of the existing code with that count (the same bytes the fixed-count scheme with that count writes), and a percentage of 0 sends the clear bytes only

**AC-3: Largest message**
Given a percentage and a clear message one byte above the largest clear length (251, 230, 222, 222, 222 for 1, 10, 25, 50 and 100 percent; percentage 0 has no limit, as a fixed count 0 has none)
When it is packed
Then the pack is refused as the package's too-long error naming the clear length and that limit, and writes 0 bytes

**AC-4: Unpack finds the count from the length**
Given every pair (p, L) with p 0 to 100 and L from 0 to its largest clear length (0 to 254 for p 0; 22,752 pairs)
When the message is packed and unpacked
Then the same row comes back with a repaired count of 0; a received length that no clear length gives is refused as `uncorrectable` with 0 values and no field named; a buffer above 254 bytes is the too-long error as today (percentages 1 to 100; with 0 nothing is checked)

**AC-5: Repair with the count of that message**
Given percentage 50 with a 40-byte clear message (20 parity bytes) and percentage 25 with a 40-byte message (10 parity bytes)
When 10 and 5 bytes are corrupted and the limit is 10 and 5, and when the seeded rows of `percent-vectors.txt` corrupt 11 bytes with limit 10 and 20 bytes with limit 0 (more than the limit allows; a refusal is certain only up to `n - t` wrong bytes, so the rows are seeded patterns the reference refuses)
Then the first two are repaired with the repaired count 10 and 5, and the last two are refused as `uncorrectable`

**AC-6: Correction limit**
Given a percentage scheme
When the limit is below 0 or above 16
Then the call is refused as `bad_limit` before any byte is read; a limit from 0 to 16 above `n / 2` of this message is lowered to it (limit 16 on the 40-byte message at 25 percent behaves as limit 5); a fixed-count scheme keeps its exact rule

**AC-7: Dispatch, vectors and compatibility**
Given handlers that declare the same percentage, a mix of two percentages, and a mix of a percentage with a count
When a dispatch call is built or run
Then the first dispatches after the repair, the mixes are refused when the call is built (before any byte is read) as a mix of counts is today; every old row of `fixtures/ecc/vectors.txt` and every old test passes unchanged; every row of `fixtures/ecc/percent-vectors.txt` (`pct`, `encp`, `inv`, `limp`, `fixp`, `badp`, `parp`, `lmtp`) is read by this package's vector test and passes; the existing timing checks pass unchanged

## Non-Functional Requirements

**Performance**
- Unpack adds at most 255 integer steps to find the clear length; the existing timing checks (load-factor helpers) pass unchanged.

**Compatibility**
- A fixed-count scheme writes the same bytes as in 0.4.0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | percentage 101, -1, percentage with count, setter order | `bad_parity` as listed; last setter wins |
| AC-2 | counts and bytes for 5 percentages x 7 lengths | table of `results_report.md`; bytes equal fixed-count scheme |
| AC-3 | largest length + 1 for 6 percentages | too-long error, 0 bytes |
| AC-4 | 22,752 round trips; impossible lengths; 255 bytes | same row; `uncorrectable`; too-long |
| AC-5 | repair p 50 / p 25 cases | counts 10 and 5; refusals |
| AC-6 | limit -1, 17, 16 on 40 bytes at 25 percent | `bad_limit`, `bad_limit`, behaves as 5 |
| AC-7 | dispatch, mixes, vector rows, old tests | as listed |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-7 | `fixtures/ecc/percent-vectors.txt` and the old `vectors.txt` | the package's vector tests | every row passes; old rows unchanged | Compatibility |

## Constraints

- Owner decision (2026-10-31): the percentage is overhead, integer, rounded up, capped at 32 (contract `message-ecc.md` 1.1.0, read it and `results_report.md`, not the reference code).
- The setting follows this package's way of setting its other scheme limits; no new refusal kind; the fixed-count setting is unchanged.
- Fit decision: a limit above `n / 2` of the message is lowered, `bad_limit` only outside 0 to 16.
- Run the package's full suite plus every reader of the shared shapes (`git grep` the readers of `vectors.txt`) before the commit.

## Risks & Mitigation

**Risk 1: Off-by-one at a rounding edge**
- *Risk*: a float `ceil` or a signed shift differs from the integer rule.
- *Mitigation*: integer arithmetic only; the 22,752-pair test (AC-4) and the vector rows catch it.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Count must match the reference exactly | AC-2, AC-4, vector rows | open | Medium |

## Contract

This task implements the contract at `_docs/02_document/contracts/library/message-ecc.md` (version 1.1.0). Read that file, not the producer task.
