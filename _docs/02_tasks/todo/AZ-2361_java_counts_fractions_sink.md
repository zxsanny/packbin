---
loop: 20
branch: dev
---

# Java refuses a BigDecimal fraction in u2, bits and packed slots, reads sized and bits counts as full u64, and grows ByteSink without int overflow

**Task**: AZ-2361_java_counts_fractions_sink
**Name**: Java fractions, counts and sink
**Description**: Java refuses a BigDecimal fraction in u2, bits and packed slots, reads sized and bits counts as full u64, and grows ByteSink without int overflow.
**Complexity**: 2 points
**Dependencies**: AZ-2329, AZ-2339 (done)
**Component**: java
**Tracker**: AZ-2361
**Epic**: AZ-2069

## Problem

Loop 20 clear gaps G1, F30, F29. G1: a `BigDecimal` 1.5 in a `u2`/`bits`/`packed` slot is silently truncated (`0101`). F30: `VarFields.java:49` (`packSized`) and `:126` (`packBits`) do `((Number) countRaw).intValue()`, so `u64 n; sized(n) b` with `n = 4294967299` packs a count that disagrees with its payload. F29: `ByteSink.ensure` (`ByteSink.java:47-55`) overflows at 2^30 bytes and then copies the buffer on every append.

## Outcome

- `BigDecimal` (and `Double`) fractions refused naming the field, as C# (AZ-2309) and the other packages.
- `packSized` and `packBits` use `borrowedCount(field, seen, Integer.MAX_VALUE)`; a count above int range is refused like `packed`.
- `ByteSink` grows with long arithmetic, capped at `Integer.MAX_VALUE - 8`, and throws a typed error at the cap.

## Acceptance Criteria

**AC-1: fraction refused**
Given `BigDecimal("1.5")` in a `u2` slot, a `bits` item and a `packed` item
When packed
Then refused naming the field; `BigDecimal("1")` packs

**AC-2: u64 count**
Given `u64 n; sized(n) b` with `n = 4294967299` and 3 bytes, and the same for `bits`
When packed
Then refused (no 12-byte packet)

**AC-3: sink growth**
Given a `ByteSink` grown past 2^30 bytes in a unit test (or the growth function tested directly with sizes near the cap)
When appended
Then no overflow; at the cap a typed error

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | BigDecimal 1.5 / 1 | refused / packs |
| AC-2 | u64 count above int | refused |
| AC-3 | growth near cap | no overflow, typed error at cap |

## Constraints

- Wire bytes of every accepted row are unchanged.
