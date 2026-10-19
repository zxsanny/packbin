---
loop: 36
branch: dev
---

# Compact text: enforce the 1 s speed bound in CI for Rust and Swift

**Task**: AZ-2665_speed_bound_in_ci
**Name**: Compact text: enforce the 1 s speed bound in CI for Rust and Swift
**Description**: Compact text: enforce the 1 s speed bound in CI for Rust and Swift
**Complexity**: 3 points
**Dependencies**: None
**Component**: compact-text
**Tracker**: AZ-2665
**Epic**: AZ-2645

## Problem

The string speed bound (CS-11) is asserted only in release for Rust (CI runs debug) and the Swift CI speed filter never selects TextSpeedTests.

## Outcome

- CI fails when the string round trip is slower than the bound in the release configuration.

## Scope

### Included
- `.github/workflows/run-suite.sh` (rust branch, swift_speed), `run-suite.test.sh`, `run-suite-swift.test.sh`.

### Excluded
- The Python and TypeScript bounds (already asserted), other packages.

## Acceptance Criteria

**AC-1: Rust release step**
Given the rust suite in CI
When it runs
Then the string speed test also runs with `--release` and asserts 1 s; a slowed encoder fails the step (HD-3)

**AC-2: Swift filter**
Given the swift speed part
When it runs
Then `TextSpeedTests` runs in the release speed run and a missing suite fails the step; a mutant filter is caught (HD-4)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | run-suite.test.sh mutant | slowed encoder fails |
| AC-2 | run-suite-swift.test.sh mutant | filter without TextSpeedTests is refused |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond `problem.md` | — | resolved | Low |
