# Rust scope check covers name-based references

**Task**: AZ-2117_rust_named_reference_scope
**Name**: Rust scope check covers name-based references
**Description**: The construction-time scope check (`rust/src/field/order.rs`, `parse_id`) covers numeric ids only.
**Complexity**: 3 points
**Dependencies**: AZ-2075
**Component**: rust
**Tracker**: AZ-2117
**Epic**: AZ-2069

## Problem

The construction-time scope check (`rust/src/field/order.rs`, `parse_id`) covers numeric ids only. Name-based references such as `eq("type", ..)` are never scope-checked; the runtime zero-progress guard still prevents the hang.

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
Given a map scheme with a `when` inside a `repeat` that names a field outside the repeat by name, When built, Then construction panics with the scope message

**AC-2**
Given every existing scheme and the typed path, When built, Then nothing valid is refused

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Track names per scope. Source: loop 11 feature-assess U4.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
