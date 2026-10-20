# Rust core: repeat, group, times, lists and dicts

**Task**: AZ-2753_rust_core_lists_and_dicts
**Name**: Rust core: repeat, group, times, lists and dicts
**Description**: Counted and repeated structures in caller-owned storage with round and slot limits and ascending dictionary keys.
**Complexity**: 5 points
**Dependencies**: AZ-2752
**Component**: rust (core)
**Tracker**: AZ-2753
**Epic**: AZ-2750

## Problem

Messages with a variable number of items need `repeat`, `group`, `times`, lists and dicts. In a heap-free core the items live in storage the caller provides, so the limits and the failure kinds must be explicit.

## Outcome

- The six kinds with the std walker's bytes and its refusals: round and slot limits (`TooMany`), the list and round agreement, dictionary keys strictly ascending.

## Scope

### Included
- The kinds, the caller-owned storage shape for lists and rounds, the limits, the key order check.

### Excluded
- Strings inside lists, dict keys and repeats (AZ-2754 adds the text path); ecc; session.

## Acceptance Criteria

**AC-1: Same bytes as std**
Given the list, group, dictionary and times schemes of `fixtures` and the std tests, rebuilt as core schemes
When the core packs the same rows
Then the bytes equal the std bytes; unpack returns the rows

**AC-2: Limits**
Given a count above the round limit, a slot count above the slot limit, storage smaller than the count
When pack and unpack run
Then `TooMany` (with the field and the limit); nothing is written past the caller's storage

**AC-3: Dictionary order**
Given keys not strictly ascending, or a duplicate key
When unpack and pack run
Then the packet is refused (as the std walker refuses it)

**AC-4: Untrusted bytes**
Given every cut and a trailing-byte copy; a count that claims more rounds than bytes
When `unpack` runs
Then an error kind only; no loop or allocation grows with the claimed count

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | differential test per kind | equal |
| AC-2 | limit cases at, above and below | `TooMany` only above |
| AC-3 | unordered and duplicate keys | refused |
| AC-4 | hostile counts | error kinds, bounded time |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.


## Risks & Mitigation

**Risk 1: Storage shape for lists is awkward to use**
- *Mitigation*: one meshbell-style row (a route of points) is written as the worked example in the test

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
