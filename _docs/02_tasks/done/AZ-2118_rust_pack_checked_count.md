# Rust pack borrowed_count uses checked_add

**Task**: AZ-2118_rust_pack_checked_count
**Name**: Rust pack borrowed_count uses checked_add
**Description**: `borrowed_count` in `rust/src/walk/pack.rs:14-27` does `raw as i64 + bias` unchecked; at 2^63 with bias -1 it panics in debug builds on caller-supplied input.
**Complexity**: 1 points
**Dependencies**: None
**Component**: rust
**Tracker**: AZ-2118
**Epic**: AZ-2069

## Problem

`borrowed_count` in `rust/src/walk/pack.rs:14-27` does `raw as i64 + bias` unchecked; at 2^63 with bias -1 it panics in debug builds on caller-supplied input.

## Outcome

Each AC below passes in the named package(s); wire bytes of packets that work today do not change.

## Scope

### Included
- rust: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1**
Given a counted field of 2^63 with bias -1, When packed, Then the existing pack error is returned (no panic) in debug and release

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Caller input, not network input. Source: loop 11 feature-assess U5.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
