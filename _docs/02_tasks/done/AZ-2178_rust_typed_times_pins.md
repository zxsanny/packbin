# Rust pins seven typed `times` shapes

**Task**: AZ-2178_rust_typed_times_pins
**Name**: Rust typed `times` shape pins
**Description**: Tests only: seven typed `SchemeItem::times` shapes that work today but are named by no test.
**Complexity**: 1 point
**Dependencies**: AZ-2086_rust_typed_times_vec
**Component**: rust
**Tracker**: AZ-2178
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (R31), owner scope A on 2026-10-05. Analyst probes of the typed `times` (AZ-2086) pass for these shapes, but no test names them, so a later change could break them unnoticed.

## Outcome

- Each shape has a test that packs it to the bytes below and round-trips the row.

## Scope

### Included
- Tests in the Rust package only. No production change; if a test fails, stop and report it instead of changing the code.

### Excluded
- Any new typed binder (typed `repeat`, `u2`, flag byte: C18).
- Behavior changes of `times`.

## Acceptance Criteria

**AC-1: Two sibling `times` sharing one count**
Given `u8 n`, `times(1, 0, ...)` and `times(3, 0, ...)` sharing count id 0, with n = 2
When packed and unpacked
Then the rows round-trip, for example n = 2, first rows (1, 2) and (3, 4), second rows (5, 6) and (7, 8), a tail `u8` 9: `0102010000000200000003000000040000000500000006000000070000000800000009`; a second `Vec` shorter than the count fails with `times at id 3: count 2, 1 rounds`.

**AC-2: `times` inside a `when` body**
Given a `when` whose body holds a `times` with one `i32` member, and a row that matches
When packed
Then the bytes are `01010105000000` and unpacking gives one element with 5.

**AC-3: `sized` with an element-local count**
Given elements `[u8 len(1), sized(2, 1)]` and rows (2, [1, 2]) and (0, [])
When packed
Then the bytes are `010202010200` and the rows round-trip.

**AC-4: A u16 count of 300**
Given a `times` with a u16 count and 300 one-byte elements
When packed and unpacked
Then the packet is 303 bytes and the rows round-trip.

**AC-5: 255 rounds with an 8-member flags per round**
Given a `times` whose element holds `flags` with eight optional `u8` members, 255 rounds
When packed and unpacked
Then the packet is 1273 bytes and every round round-trips (round i = 0..254 holds member k iff bit k of i is set: 2 + 255 + 1016 bytes).

**AC-6: Primitive and tuple elements**
Given `Vec<u8>` elements, and `Vec<(i32, i32)>` elements
When packed
Then `[1, 2, 3]` with count 3 packs `0103010203` (type byte, count, the bytes) and the tuple rows (3, 4), (5, 6) with count 2 pack `010203000000040000000500000006000000`, and both round-trip.

**AC-7: A `PackSession` round trip of a times row**
Given an open `PackSession` pair and a typed row with a `times`
When the row is packed on one side and unpacked on the other
Then the peer reads the same row, and a pack that fails (count and `Vec` length disagree) leaves the next pack readable.

## Non-Functional Requirements

**Reliability**
- Tests are deterministic and need no sleeps.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1..AC-7 | the seven shapes | bytes as above; rows round-trip |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1..AC-7 | none beyond the unit tests | n/a | covered by the unit tests | Reliability |

## Constraints

- Tests only. Done in loop 13: every byte string above was re-derived from a real pack run (the two AC-6 strings in the first draft were wrong and are corrected here).
- Files stay under 500 lines; put the tests in a new file.

## Risks & Mitigation

**Risk 1: A probe value in this spec is wrong**
- *Risk*: the analyst probes were typed from memory of the run.
- *Mitigation*: the worker confirms each byte string against the real pack output and reports any difference instead of editing production code.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the unpinned shapes themselves | coordinator | resolved | Low |
