# C# group as list or dict element throws KeyNotFoundException on unpack

**Task**: AZ-2119_csharp_group_list_element
**Name**: C# group as list or dict element throws KeyNotFoundException on unpack
**Description**: `UnpackList` and `UnpackDict` read `one[child.Name]`, but a group never stores a value under its name, so a list or dict whose element is a group throws `KeyNotFoundException` on unpack.
**Complexity**: 3 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2119
**Epic**: AZ-2069

## Problem

`UnpackList` and `UnpackDict` read `one[child.Name]`, but a group never stores a value under its name, so a list or dict whose element is a group throws `KeyNotFoundException` on unpack. A valid scheme lets an exception escape unpack. Found in loop 11 round 2; it predates the loop.

## Outcome

Each AC below passes; wire bytes of packets that work today do not change.

## Scope

### Included
- csharp: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).

## Acceptance Criteria

**AC-1**
Given a list whose element is a group of two fields, When a valid packet is unpacked, Then the rows are returned (the value shape matches what the other five packages return for the same scheme) and no exception escapes

**AC-2**
Given a dict whose value is a group, When a valid packet is unpacked, Then the same

**AC-3**
Given every existing test, When they run, Then they pass unchanged

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep. *Mitigation*: First check what the other five packages return for a group element so the shape is the same. Source: loop 11 round 2 C# worker.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a worker discovery; refine the Given/When/Then before the loop that takes it | coordinator | open | Low |
