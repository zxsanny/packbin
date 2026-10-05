# C# pack drops a When directly under a combined Flags group

**Task**: AZ-2120_csharp_when_under_flags_pack
**Name**: C# pack drops a When directly under a combined Flags group
**Description**: `FlagGroup.Compute` checks `IsPresent(values, "")` for a `When`, so its bit stays clear and its field is not written on pack: `Mode=1, Speed=7, Heading=90` packs to `0101025a00` and drops `Speed`, while unpack of `01 01 03 07 5a00` is correct.
**Complexity**: 2 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2120
**Epic**: AZ-2069

## Problem

`FlagGroup.Compute` checks `IsPresent(values, "")` for a `When`, so its bit stays clear and its field is not written on pack: `Mode=1, Speed=7, Heading=90` packs to `0101025a00` and drops `Speed`, while unpack of `01 01 03 07 5a00` is correct. Pack and unpack disagree. Found in loop 11 round 2; it predates the loop.

## Outcome

Each AC below passes; wire bytes of packets that work today do not change.

## Scope

### Included
- csharp: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).

## Acceptance Criteria

**AC-1**
Given a combined `Flags(...)` containing a `When` on Mode, When `Mode=1, Speed=7, Heading=90` is packed, Then the bytes are `01 01 03 07 5a00` and unpack returns the same row

**AC-2**
Given the other five packages, When the same scheme is packed, Then the bytes match C#

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep. *Mitigation*: Make Compute treat a When like a Group; check the other packages for the same shape. Source: loop 11 round 2 C# worker.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a worker discovery; refine the Given/When/Then before the loop that takes it | coordinator | open | Low |
