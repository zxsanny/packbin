# Pin the split-form reference bytes in TypeScript and C# tests

**Task**: AZ-2115_split_form_reference_bytes
**Name**: Pin the split-form reference bytes in TypeScript and C# tests
**Description**: Only Java asserts the split-form reference row; C# tests a different row and TypeScript has no split-form test.
**Complexity**: 2 points
**Dependencies**: AZ-2091
**Component**: typescript, csharp
**Tracker**: AZ-2115
**Epic**: AZ-2069

## Problem

Only Java asserts the split-form reference row; C# tests a different row and TypeScript has no split-form test. AZ-2076 AC-5 and AZ-2077 AC-4 require the bytes to match across languages.

## Outcome

Each AC below passes in the named package(s); wire bytes of packets that work today do not change.

## Scope

### Included
- typescript, csharp: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1**
Given `u8 sid`, split `flagByte m`, `when(sid==9) u8 shape`, `m.bit(u16 heading)`, When `{sid:9, shape:4, heading:90}` and `{sid:1}` are packed, Then the bytes are `010901045a00` and `010100`, and both unpack to the same rows, in TypeScript and C#

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: TypeScript part could fold into AZ-2091; Python is AZ-2100. Source: loop 11 feature-assess G4.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |

## Loop 16 progress (2026-10-06)

| Part | Package | State |
|------|---------|-------|
| AC-1 reference rows `010901045a00` and `010100` | TypeScript | done in batch 3 (tests only; both rows already packed correctly at HEAD) |
| AC-1 | C# | held until the C# multi-target work is committed |
