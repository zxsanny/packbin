# TypeScript accepts u64 counts for sized, packed and times

**Task**: AZ-2112_typescript_u64_counts
**Name**: TypeScript accepts u64 counts for sized, packed and times
**Description**: A valid packet whose count field is a `u64` (`01 0300000000000000 616263`) is returned as `ok:false` by `sized`, `packed` and `times` in TypeScript (`validCount` accepts only `number`); the other four packages accept it.
**Complexity**: 2 points
**Dependencies**: AZ-2072
**Component**: typescript
**Tracker**: AZ-2112
**Epic**: AZ-2069

## Problem

A valid packet whose count field is a `u64` (`01 0300000000000000 616263`) is returned as `ok:false` by `sized`, `packed` and `times` in TypeScript (`validCount` accepts only `number`); the other four packages accept it. `bits` was restored in loop 11. README: the count is "an earlier integer".

## Outcome

Each AC below passes in the named package(s); wire bytes of packets that work today do not change.

## Scope

### Included
- typescript: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1**
Given `u64 n`, then `sized` counting on it, When `01 0300000000000000 616263` is unpacked, Then the row is returned (`p = 616263`); the same for `packed` and `times`

**AC-2**
Given a `u64` count above 2^53, When unpacked, Then the interim error value is returned, no throw, no hang

**AC-3**
Given every existing test, When they run, Then they pass unchanged

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Could fold into AZ-2090. Source: loop 11 feature-assess G1.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
| Loop 13 assessment (T6): the pack leg is unwritten here. A `u64` field takes a bigint on pack, but `sized` / `packed` / `times` refuse a bigint as the count ("bad count" / "count missing"), so an unpacked row cannot be repacked; `bits` works both ways. Cover the pack leg with the unpack ACs | coordinator | open | Low |
