# Rust scope check covers name-based references

**Task**: AZ-2117_rust_named_reference_scope
**Name**: Rust scope check covers name-based references
**Description**: The construction-time scope check (`rust/src/field/order.rs`, `parse_id`) covers numeric ids only.
**Complexity**: 4 points
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

**AC-3** (added by the loop 13 feature assessment, R19 / X3)
Given `u8 n(0)`, `times(1, 0, [u8 x(1)])` and then `when(2, eq(1, 1), [u8 w(2)])` (also the `repeat` form, a `sized(2, p, 1)` counting the inner field after the body, and the typed `Vec<E>` `times` form of AZ-2086), When built, Then construction panics naming the `when` or count at id 2 and the field (a field inside a `repeat` / `times` body is not visible after it, README; C++ `find_ref` skips container bodies)

**AC-4** (added by the loop 13 feature assessment, R19)
Given a `when` or a count that names an id that is never declared, When built, Then construction panics naming the id; every scheme in the suite (route `when(9, eq(3, 1))`, F-AC-1, AZ-2086 AC-1/AC-5) still builds

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep into neighbouring tickets. *Mitigation*: Track names per scope. Source: loop 11 feature-assess U4.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a feature-assess row; refine the Given/When/Then with the implementer before the loop that takes it | coordinator | open | Low |
| Loop 13 assessment (R19, X3): today Rust builds a `when` / count naming a field inside an earlier `times` / `repeat` body, or an undeclared name, and the value is silently lost (typed `[u8 n, times(1,0,Vec<E>,[u8 x]), when(2, eq(1,1), [u8 w])]` with w = 5 packs `01 01 01`, unpack w = 0). Identical on `ce85fe0`; TypeScript, C# and Java refuse it. AC-3 and AC-4 added; add the construct vector `when_names_inner_field_after_times` to `fixtures/hostile/cases.txt` | coordinator | open | Medium |
