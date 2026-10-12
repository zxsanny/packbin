---
loop: 20
branch: dev
---

# A split-form `times` count written after the flag byte that is 0 while the row gives a list of values is refused in all six packages; a lone scalar stays silent

**Task**: AZ-2356_count_zero_after_byte_list_error
**Name**: Count 0 after the byte with a list
**Description**: In the split form, a `times` whose count is written after the flag byte and equals 0 while the row gives a list is refused naming the member; with a lone scalar it packs zero rounds (the C# rule).
**Complexity**: 2 points
**Dependencies**: AZ-2335, AZ-2331 (done)
**Component**: typescript, python, java, cpp (probe and align); csharp, rust (already; pin with a test)
**Tracker**: AZ-2356
**Epic**: AZ-2069

## Problem

Owner decision 3 of loop 20 (assessment U2, option A). C# (a list only) and Rust error; the other four were not probed for this row. AZ-2335 already refuses count 0 with values outside the split form.

## Outcome

- Same outcome in six packages: list → error naming the member; lone scalar → zero rounds, bytes as today.

## Scope

### Included
- Probe each package first and write the per-package before/after row in the batch report; change only those that differ; a test in all six.

### Excluded
- The non-split form (AZ-2335, done).

## Acceptance Criteria

**AC-1: list refused**
Given a split flag bit whose `times` count is written after the byte, count 0, values `[5, 6]`
When packed in each of the six packages
Then an error naming the member

**AC-2: lone scalar packs**
Given the same scheme with count 0 and a lone scalar
When packed
Then zero rounds and the same hex in six packages

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | count 0 + list, split | error, six packages |
| AC-2 | count 0 + scalar, split | same hex, six packages |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_split_count_zero_after_byte_list` (AZ-2367) | error | — |

## Constraints

- C++: arm stack and flash measured (`cpp/src/core`); stop if the flash margin goes below 32 B.
