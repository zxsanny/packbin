# Position bytes

**Task**: AZ-1919_position_bytes
**Name**: Position bytes
**Description**: Each language packs and unpacks the position row to the golden hex.
**Complexity**: 5 points
**Dependencies**: AZ-1913_test_infrastructure
**Component**: Blackbox Tests
**Tracker**: AZ-1919
**Epic**: AZ-1865

## Problem

A caller cannot tell that the six packages agree unless each one packs and unpacks the same position row.

## Outcome

- Pack of the position values is `4001000065cd1d00a3e1110100` in all six languages
- Unpack of that hex returns type 64, sid 1, lat 500000000, lon 300000000, profile 1, and motion field count 0
- Packing the row twice yields a byte mismatch count of 0

## Scope

### Included

- FT-P-01, FT-P-02, FT-P-03, SM-01, SM-02
- Comparison to `_docs/00_problem/input_data/expected_results/results_report.md` position rows

### Excluded

- Flag width, groups, speed, and the tag gate

## System Under Test Boundary

The test calls `pack` and `unpack` on the real package in each language. It does not stub, fake, or replace a package. Registries are outside the product and are not called. Results are compared to `results_report.md`.

## Acceptance Criteria

**AC-1: Position pack**
Given the position values
When each language packs them
Then the hex is `4001000065cd1d00a3e1110100` and the length is 13

**AC-2: Position unpack**
Given that hex
When each language unpacks it
Then the five fields match and the motion field count is 0

**AC-3: The six languages agree**
Given the position row packed twice
When the bytes are compared
Then the mismatch count is 0

## Non-Functional Requirements

**Compatibility**
- The same hex in C#, TypeScript, Python, Rust, C++, and Java

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | pack of the position values | the golden hex |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | position values | pack in each language | hex `4001000065cd1d00a3e1110100`, length 13 | — |
| AC-2 | that hex | unpack in each language | five fields, motion field count 0 | — |
| AC-3 | the row packed twice | compare the bytes | mismatch count 0 | — |

## Constraints

- The fixture file is `fixtures/golden.hex`
- No registry call

## Risks & Mitigation

**Risk 1: A language drifts**
- *Risk*: one package returns a different hex
- *Mitigation*: mismatch count above 0 fails the scenario

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
