---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ core: static scheme tables, type number, field order

**Task**: AZ-2061_cpp_core_schemes
**Name**: C++ core schemes
**Description**: Schemes are constant field tables bound to row members, picked by type number, and checked for field order at compile time or by a validate call.
**Complexity**: 5 points
**Dependencies**: AZ-2060_cpp_core_scalars
**Component**: cpp
**Tracker**: AZ-2061
**Epic**: AZ-2059

## Problem

Today a scheme is built at run time from `std::vector`, `std::function` and `std::shared_ptr`, and an order error throws (`problem.md` blockers 1, 2).

## Outcome

- A scheme is a constant table in flash, bound to row members without `std::function`.
- Unpack picks one of several schemes by type number with no heap and no exceptions.
- The `scheme-field-order` rules are enforced at compile time for constant schemes and by `validate()` for schemes built at run time.

## Scope

### Included
- Constant field table and member binding for the scalar kinds from AZ-2060.
- Type-number dispatch over several schemes.
- Compile-time order and anchor check; runtime `validate()` returning `SchemeInvalid` with the field id.

### Excluded
- Grouped/conditional kinds (AZ-2062), counted/variable kinds (AZ-2063), session (AZ-2065).

## Acceptance Criteria

**AC-1: Unknown type number**
Given two schemes with different type numbers and a packet whose type number matches neither
When the core unpacks
Then the result is `TypeMismatch` with offset and field id, and no row handler runs (S4).

**AC-2: Matching type number**
Given the same schemes and each scheme's own vector
When the core unpacks
Then the matching scheme's row is filled and mismatched fields are 0.

**AC-3: Order error at compile time**
Given each invalid constant scheme from the `scheme-field-order` criteria (gap, repeated id, wrong anchor, `when` naming an id not yet walked)
When it is compiled
Then compilation fails with a message naming the field id (S9; feature AC-7).

**AC-4: Order error at run time**
Given the same invalid schemes built at run time
When `validate()` runs
Then the result is `SchemeInvalid` with that field id, and a pack with that scheme writes 0 bytes.

## Non-Functional Requirements

**Compatibility**
- Same core profile as AZ-2060. Scheme tables are `const`; no global mutable state.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | unknown type number | `TypeMismatch`, 0 handler calls |
| AC-2 | each known type number | row filled, 0 mismatched fields |
| AC-4 | each invalid runtime scheme | `SchemeInvalid` + field id, 0 bytes written |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | one compile-fail source per invalid scheme | compile on GCC and Clang | fails; message names the id | — |

## Constraints

- Decision D-1 A (fit card 3): one core; the field-order rules exist once, in the core.
- `scheme-field-order` criteria stay in force.

## Risks & Mitigation

**Risk 1: Compile-time message**
- *Risk*: a failed constant evaluation may not show the id in every compiler's message.
- *Mitigation*: the failing check carries the id in its text; the compile-fail test greps for it on GCC and Clang.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
