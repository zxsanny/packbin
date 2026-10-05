---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ core: grouped and conditional kinds

**Task**: AZ-2062_cpp_core_grouped_kinds
**Name**: C++ core grouped kinds
**Description**: The core packs and unpacks `flags`, `flag_byte` bits, `when(eq(...))` and `group` with the same bytes as today.
**Complexity**: 3 points
**Dependencies**: AZ-2061_cpp_core_schemes
**Component**: cpp
**Tracker**: AZ-2062
**Epic**: AZ-2059

## Problem

Flags, flag bytes, conditional and grouped fields only exist in the dynamic walker, which needs exceptions and the heap.

## Outcome

- `flags`, `flag_byte` + bits, `when(eq(...))` and `group` (nested and continuing) work in constant core schemes.
- Every vector the host suite asserts for those kinds gives 0 mismatched bytes and 0 mismatched fields through the core.

## Scope

### Included
- The four kinds in the core, their order/anchor rules in the compile-time and runtime checks from AZ-2061.
- Host unit tests for every existing vector of these kinds.

### Excluded
- Counted and variable kinds (AZ-2063).

## Acceptance Criteria

**AC-1: Same bytes for grouped kinds**
Given every `flags`, `flag_byte`, `when` and `group` vector asserted in `cpp/tests` today
When the core packs each row and unpacks each hex
Then mismatched bytes are 0 and mismatched fields are 0 (feature AC-3 for those vectors).

**AC-2: Flags overflow is a value**
Given a `flags` group with more bits than its byte holds
When the scheme is checked
Then compile time fails for a constant scheme and `validate()` returns `SchemeInvalid` with the field id for a runtime scheme; 0 exceptions.

**AC-3: A clear flag is not stored as 0**
Given a row whose conditional fields are absent
When it is packed and unpacked
Then the absent fields stay absent after unpack (interaction risk "A clear flag is stored as 0").

## Non-Functional Requirements

**Compatibility**
- Same core profile as AZ-2060.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each grouped/conditional vector | 0 mismatched bytes/fields |
| AC-2 | flags overflow, constant and runtime | compile error / `SchemeInvalid` + id |
| AC-3 | absent conditional fields round trip | absent after unpack |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/golden.hex` row | pack through the core | `4001000065cd1d00a3e1110100` | — |

## Constraints

- Feature `restrictions.md` § Embedded profile.

## Risks & Mitigation

**Risk 1: Group continuation rules**
- *Risk*: continuing groups have subtle id rules.
- *Mitigation*: reuse every existing group vector; none may be dropped.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
