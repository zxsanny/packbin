# Groups and leftover bytes

**Task**: AZ-1921_groups
**Name**: Groups
**Description**: A conditional group, a repeated group, and a leftover byte.
**Complexity**: 3 points
**Dependencies**: AZ-1913_test_infrastructure
**Component**: Blackbox Tests
**Tracker**: AZ-1921
**Epic**: AZ-1865

## Problem

A group that does not match must add nothing, a repeated group must yield one value per complete group, and one leftover byte is an error.

## Outcome

- A conditional group adds 0 bytes, or a width equal to the group
- A buffer of whole groups yields one value per group
- One leftover byte, or one byte after a finished list, is an error and 0 values

## Scope

### Included

- FT-P-06, FT-P-07, FT-N-02

### Excluded

- The position row and the tag gate

## System Under Test Boundary

The test calls `pack` and `unpack` on the real package. Results are compared to `results_report.md` groups rows.

## Acceptance Criteria

**AC-1: Conditional group**
Given a condition that misses, then one that matches
When the list is packed
Then the miss adds 0 bytes and the match adds the group width

**AC-2: Repeated group**
Given a buffer of whole groups
When it is unpacked
Then the value count equals the number of groups

**AC-3: Leftover byte**
Given one byte left over, or one byte after a finished list
When it is unpacked
Then the result is an error and the value count is 0

## Non-Functional Requirements

**Reliability**
- A leftover byte does not return a partial value

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | unpack with one leftover byte | error, value count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | conditional group | pack | 0 extra bytes, or the group width | — |
| AC-2 | whole groups | unpack | one value per group | — |
| AC-3 | 1 leftover byte | unpack | error, value count 0 | Reliability |

## Constraints

- No registry call

## Risks & Mitigation

**Risk 1: A partial group is accepted**
- *Risk*: one leftover byte returns a value
- *Mitigation*: AC-3 requires value count 0

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
