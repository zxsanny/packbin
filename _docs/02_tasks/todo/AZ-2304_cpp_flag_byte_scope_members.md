---
loop: 18
branch: dev
---

# C++ flag byte inside a flags member or flag-bit child is not visible to later bits

**Task**: AZ-2304_cpp_flag_byte_scope_members
**Name**: C++ flag-byte scope parity
**Description**: A flag byte read inside a `flags` member or a flag-bit child is a conditional scope, as a closed `when` already is, so a later bit outside it is refused at scheme construction in C++ like in Rust, TypeScript and Java.
**Complexity**: 2 points
**Dependencies**: AZ-2135_split_bits_field_order (the C++ `when` part, done in loop 16)
**Component**: cpp
**Tracker**: AZ-2304
**Epic**: AZ-2069

## Problem

Owner decision 2026-10-06 (AZ-2135 progress table): follow-up spec. `find_flag_byte` in `cpp/include/packbin/order.hpp` skips a closed `when` and a closed container, but a flag byte read inside a `flags` member or a flag-bit child can still be found by a later flag bit of the same container. Rust, TypeScript and Java treat all three as conditional scopes, so the same scheme builds in C++ and is refused elsewhere, or packs bytes that its own unpack does not read.

## Outcome

- A flag bit binds only to a flag byte of its own container that was read before it and is not inside a closed `when`, `flags` member or flag-bit child.
- Schemes that build today and do not use such a byte are unchanged (golden, route and motion examples).

## Scope

### Included
- C++ scheme check and the unpack/pack code the new rows need; the Rust, TypeScript and Java twins are read to confirm the rule, not changed.
- Compile-time (`constexpr`) and host paths, and the embedded flash budget check.

### Excluded
- Other packages; the error label (C15).

## Acceptance Criteria

**AC-1: a byte inside a flags member is not visible to a later bit**
Given a scheme with a `flags` member that contains `flag_byte(0)`, followed outside it by `flag_bit(0, u8 b)`
When the scheme is built
Then building fails with `SchemeInvalid` naming `b`, as Rust, TypeScript and Java refuse it.

**AC-2: a byte inside a flag-bit child is not visible to a later bit**
Given a `flag_bit` whose child contains `flag_byte(1)`, followed outside it by `flag_bit(1, u8 b)`
When the scheme is built
Then building fails with `SchemeInvalid` naming `b`.

**AC-3: a byte read before the container keeps working**
Given `flag_byte(0)` at the container level, then a `flags` member with its own `flag_byte(0)` and bits, then `flag_bit(0, u8 b)` outside
When the scheme is built and a row packed and unpacked
Then `b` binds to the outer byte, the bytes equal the Rust bytes for the same scheme (derived from a run of the Rust package), and both directions round-trip.

**AC-4: existing examples unchanged**
Given the golden, route and motion examples and every scheme in `cpp/tests`
When they are built and packed
Then bytes and results are unchanged, and the embedded flash size stays within the current budget.

## Non-Functional Requirements

**Compatibility**
- No wire change for schemes that build today and use no such byte.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the AC-1 scheme | `SchemeInvalid` naming `b` (compile-fail or runtime check, like the AZ-2135 AC-2 test) |
| AC-2 | the AC-2 scheme | `SchemeInvalid` naming `b` |
| AC-3 | outer-byte scheme, one row | Rust bytes; round trip |
| AC-4 | golden, route, motion, existing suite | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | C++ host build | pack with C++, unpack with Rust through the existing ring if the scheme fits it, otherwise by a hex comparison | same bytes | — |

## Constraints

- ADR-001: the C++ core implements the rule itself. Files stay at or under 500 lines.

## Risks & Mitigation

**Risk 1: flash size**
- *Risk*: the check grows code on the 8 KB class targets.
- *Mitigation*: the check is `constexpr`; measure flash before and after.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Exact scheme shapes and Rust bytes in the ACs are derived by the spec writer; the worker re-derives them from a run of Rust, TypeScript and Java first | coordinator | open | Low |
