# Position round trips

**Task**: AZ-1922_speed
**Name**: Speed
**Description**: 100000 position round trips finish within one second, with no GPU.
**Complexity**: 3 points
**Dependencies**: AZ-1913_test_infrastructure
**Component**: Blackbox Tests
**Tracker**: AZ-1922
**Epic**: AZ-1865

## Problem

The library is a CPU function. A slow path or a GPU requirement would fail the release bound.

## Outcome

- 100000 pack-then-unpack round trips of the position row finish in at most 1 second on one core
- The run does not load a GPU library

## Scope

### Included

- NFT-PERF-01, NFT-RES-LIM-01, R-01

### Excluded

- The tag gate

## System Under Test Boundary

The test calls `pack` and `unpack` on the real package in a loop. It does not stub the walker. Elapsed time is compared to `results_report.md` speed row 1.

## Acceptance Criteria

**AC-1: One second**
Given the position row and one core
When pack then unpack runs 100000 times
Then elapsed time is at most 1 second

**AC-2: No GPU**
Given that loop
When it runs
Then no GPU library is loaded

## Non-Functional Requirements

**Performance**
- 100000 round trips ≤ 1 second

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the timed loop | elapsed time ≤ 1 second |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | position, 100000 trips, one core | elapsed time | ≤ 1 second | Performance |
| AC-2 | the same loop | loaded libraries | no GPU library | — |

## Constraints

- No server and no GPU

## Risks & Mitigation

**Risk 1: A cold start dominates the sample**
- *Risk*: the first call includes process startup
- *Mitigation*: the bound is on the 100000 calls, not on container boot

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
