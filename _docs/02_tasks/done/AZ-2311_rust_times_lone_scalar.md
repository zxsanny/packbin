---
loop: 18
branch: dev
---

# Rust map API broadcasts a lone scalar to every round of a times

**Task**: AZ-2311_rust_times_lone_scalar
**Name**: Rust lone scalar in times
**Description**: A Rust map scheme with `times` and a lone scalar for a name in the round carries the scalar in every round, as TypeScript, Python, Java and C# do.
**Complexity**: 2 points
**Dependencies**: AZ-2182_csharp_nonlist_round_value (done; the owner's option A)
**Component**: rust
**Tracker**: AZ-2311
**Epic**: AZ-2069

## Problem

Loop 17 assessment E6 and the AZ-2182 spec-writer comment. Owner option A of AZ-2182: broadcast a lone scalar to every round, refuse a lone collection. Rust map `times` puts a lone scalar in round 0 only, so the same row gives different bytes in Rust.

## Outcome

- Rust map `times` with a lone scalar gives the bytes the other four packages give.

## Scope

### Included
- Rust map API pack of `times` (and `repeat` if the probe shows the same).

### Excluded
- Typed Rust rows; a lone collection rule (already loud); other packages.

## Acceptance Criteria

**AC-1: probe**
Given the AZ-2182 `times` scheme (`01 02 01 04 01 05` shape; re-derive bytes from a run of TypeScript and Java first)
When Rust packs a lone scalar
Then the batch report records the bytes Rust gives now and the bytes of the other packages

**AC-2: every round carries the scalar**
Given the same scheme and row in Rust
When packed
Then every round holds the scalar and the bytes equal the other packages' bytes

**AC-3: lists and unchanged paths**
Given a per-round list, and the existing Rust suite
When packed and run
Then bytes and results are unchanged

## Non-Functional Requirements

**Compatibility**
- Only rows with a lone scalar change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | lone scalar under `times` (and `repeat` if affected) | all rounds |
| AC-3 | per-round list, suite | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | rounds ring | cross-package bytes | equal | — |

## Constraints

- ADR-001: Rust implements it itself. Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |

## Loop 18 result (2026-10-10)

Done in loop 18 wave 1 (rust). `slice_times` broadcasts a lone non-list value to every round; bytes from a TypeScript run: n=2 lone x=1, y=[4,5] `010201040105`, n=3 `0103010401050106`. `repeat` has no lone-scalar form in the map API. `times_lone_value_tests`.
