# Rust core: flags, bits, u2, packed, sized and when

**Task**: AZ-2752_rust_core_bits_and_when
**Name**: Rust core: flags, bits, u2, packed, sized and when
**Description**: The bit-level and conditional field kinds in the heap-free core, byte-identical to the std walker.
**Complexity**: 5 points
**Dependencies**: AZ-2749
**Component**: rust (core)
**Tracker**: AZ-2752
**Epic**: AZ-2750

## Problem

The base core (AZ-2749) has scalars and fixed bytes only. meshbell's messages use flag bytes, bit fields, packed lists and conditional members.

## Outcome

- `flags`, flag bytes, `bits`, `u2`, `packed`, `sized` and `when` with the std walker's bytes, errors and construction checks.

## Scope

### Included
- The seven kinds, their scheme checks (a `when` source id out of range, a `when` after its source, an empty body, a duplicate name in one scope) and their `Row` access.

### Excluded
- `repeat`, `group`, `times`, lists, dicts (AZ-2753); text; ecc; session.

## Acceptance Criteria

**AC-1: Same bytes as std**
Given the schemes of `fixtures` and the flag, bit and `when` cases of the std tests, rebuilt as core schemes
When the core packs the same rows
Then the bytes equal the std bytes, and unpack gives the rows back

**AC-2: Scheme refusals**
Given a `when` source above the id range, a `when` that reads a later field, an empty `when` body, a duplicate member name
When `validate` runs
Then `SchemeInvalid` for each, before any byte moves

**AC-3: Untrusted bytes**
Given every cut and a trailing-byte copy of each packet
When `unpack` runs
Then `ShortPacket` or `TrailingBytes`; never a panic; a `when` whose source is absent keeps its members off

**AC-4: Absent members**
Given a row where an optional member is absent
When pack and unpack run
Then the flag bit or `when` match follows presence, as the std walker does

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | differential test per kind | equal |
| AC-2 | one case per refusal | `SchemeInvalid` |
| AC-3 | cut/extended packets | error kinds only |
| AC-4 | presence matrix | equal to std |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.


## Risks & Mitigation

**Risk 1: A bit-order or bias mistake that only shows on some values**
- *Mitigation*: the vectors file and a range sweep run in the differential test

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
