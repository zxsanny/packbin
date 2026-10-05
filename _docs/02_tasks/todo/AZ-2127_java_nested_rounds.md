# Java nested `repeat` / `times` inside a round as per-round nested lists

**Task**: AZ-2127_java_nested_rounds
**Name**: Java nested rounds
**Description**: A `repeat` or `times` nested inside a `repeat`/`times` round packs and unpacks one inner list per outer round, and the loop 12 construction refusal is removed.
**Complexity**: 3 points
**Dependencies**: AZ-2089_java_forward_refs_bool
**Component**: java
**Tracker**: AZ-2127
**Epic**: AZ-2069

## Problem

Found by the loop 12 re-review of AZ-2089 (High #1). Inner rounds read every item from index 0 of the whole row list: `repeat(0, u8 n, times(1, 0, u8 v))` with `{n:[1,1], v:[5,7]}` repacked as `0101050105` (7 became 5, no error). At HEAD repeat→times threw an NPE and times→times was already corrupt. C++ keeps per-item arrays for nested `times`.

User decision 2026-10-05: loop 12 refuses a `repeat`/`times` nested inside a `repeat`/`times` round at construction; this task brings the shape back correctly.

## Outcome

- The inner rounds of each outer round are stored as one list per outer round (`v: [[5], [7]]`), aligned with the outer rounds (`null` for an outer round that skipped the inner group).
- Pack reads the same shape, so every nested row round-trips; the construction refusal is removed.

## Acceptance Criteria

**AC-1: repeat → times round-trips**
Given `repeat(0, u8 n, times(1, 0, u8 v))` and `{n:[1,1], v:[[5],[7]]}`, When packed and unpacked, Then `0101050107` and the same row

**AC-2: times → times and repeat → repeat**
Given the same nesting with `times` outer, and `repeat` inner, When packed and unpacked, Then each round-trips with per-round inner lists

**AC-3: matches C++**
Given the AC-1 scheme in C++ with the same values, When packed, Then the same bytes

**AC-4: nested row in a round (loop 12 assessment G2)**
Given `repeat(0, group(get g, set g, u8(0, v)))` on a `Map` row
When `{g:[{v:1},{v:2}]}` is packed and `010102` is unpacked
Then the bytes are `010102`, `g == [{v:1},{v:2}]`, and `BinaryPacker.unpack` returns an error value (never throws) for any packet of this scheme. Today pack throws `0: expected int, got null` and unpack throws `IllegalArgumentException: expected map` (same before loop 12; AZ-2101's Excluded line points back to AZ-2089, which did not fix it).

## Constraints

- ADR-001: Java only. Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a review finding; refine before the loop that takes it | coordinator | open | Low |
