# Hostile session unpack tests for C#, Java and Rust

**Task**: AZ-2114_hostile_session_tests
**Name**: Hostile session unpack tests for C#, Java and Rust
**Description**: Python and TypeScript test that a session waiter unpacking a hostile payload returns the same error as clear unpack (AZ-2071/2072 AC-7).
**Complexity**: 2 points
**Dependencies**: None
**Component**: csharp, java, rust
**Tracker**: AZ-2114
**Epic**: AZ-2069

## Problem

Python and TypeScript test that a session waiter unpacking a hostile payload returns the same error as clear unpack (AZ-2071/2072 AC-7). C#, Java and Rust route correctly by reading but have no test.

## Outcome

Each AC below passes in the named package(s); wire bytes of packets that work today do not change.

## Scope

### Included
- csharp, java, rust: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1**
Given an opened session pair in each of C#, Java and Rust, When the waiter unpacks the session-padded packet whose clear bytes are `01 00 ff` (zero-progress scheme), Then it returns the same error as clear unpack within 1 s

**AC-2**
Given the same pair, When a valid message follows, Then it unpacks (the receive counter advanced by one)

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Rust part could fold into AZ-2105. Source: loop 11 feature-assess G3.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
