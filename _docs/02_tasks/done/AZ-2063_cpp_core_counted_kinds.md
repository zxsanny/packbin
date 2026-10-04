---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ core: counted and variable kinds with caller storage

**Task**: AZ-2063_cpp_core_counted_kinds
**Name**: C++ core counted kinds
**Description**: The core packs and unpacks `utf8`, `bytes`, `sized`, `repeat`, `times`, `u2`, `bits`, `packed`, `list` and `dict` into caller storage with maximum counts.
**Complexity**: 5 points
**Dependencies**: AZ-2061_cpp_core_schemes
**Component**: cpp
**Tracker**: AZ-2063
**Epic**: AZ-2059

## Problem

Variable-size fields unpack into `std::string`, `std::vector` and `std::map` today, which firmware cannot use (`problem.md` blocker 2).

## Outcome

- Strings and byte blocks unpack as a borrowed view into the input buffer, or into a fixed caller destination.
- Counted kinds unpack into caller arrays with a maximum count; exceeding it is `TooMany`, never truncation.
- Every existing vector of these kinds gives the same bytes through the core.

## Scope

### Included
- The ten kinds in the core, with order rules wired into the AZ-2061 checks.
- Borrowed view and fixed-destination forms for `utf8` and `bytes`.
- Host unit tests for every existing vector of these kinds.

### Excluded
- Grouped kinds (AZ-2062), session (AZ-2065).

## Acceptance Criteria

**AC-1: Same bytes for counted kinds**
Given every `utf8`, `bytes`, `sized`, `repeat`, `times`, `u2`, `bits`, `packed`, `list` and `dict` vector asserted in `cpp/tests` today
When the core packs each row and unpacks each hex
Then mismatched bytes are 0 and mismatched fields are 0.

**AC-2: Too many groups**
Given a `repeat` with one more group than the caller storage holds
When the core unpacks
Then the result is `TooMany` with offset and field id, and the fields read before it keep their values (S5; feature AC-6).

**AC-3: Borrowed string and bytes**
Given a packet with a 40-byte `utf8` field and a 16-byte `bytes` field
When it is unpacked into a row whose members are pointer + length views
Then each view points into the input buffer, the lengths are 40 and 16, and bytes copied by the core are 0 (feature AC-8).

**AC-4: Fixed destination too small**
Given the same packet and a row with a fixed `char[16]` string destination
When it is unpacked
Then the result is `TooMany`; a borrowed view of the same field has no limit (S6).

**AC-5: Unpack never returns part of a short buffer**
Given a counted field whose declared count runs past the end of the packet
When it is unpacked
Then the result is `ShortPacket` with offset and field id (interaction risk "Unpack returns part of a short buffer").

## Non-Functional Requirements

**Compatibility**
- Same core profile as AZ-2060. No allocation for any kind.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each counted/variable vector | 0 mismatched bytes/fields |
| AC-2 | one group too many | `TooMany` + offset + id, earlier fields kept |
| AC-3 | 40-byte utf8 + 16-byte bytes as views | views inside input, lengths 40/16 |
| AC-4 | `char[16]` destination for 40 bytes | `TooMany` |
| AC-5 | count past packet end | `ShortPacket` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | language-pair hex for `user` and `nested` rows | unpack through the core | 0 mismatched fields | — |

## Constraints

- Fit card 2: C++-only allocation and zero-copy budget (amended project out-of-scope line, 2026-10-04).
- Exceeding a maximum count is an error, never truncation.

## Risks & Mitigation

**Risk 1: dict keys without a map**
- *Risk*: `dict` has string keys and the core has no map type.
- *Mitigation*: dict unpacks into caller arrays of key view + value; order follows the wire.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | resolved | Low |
