---
loop: 58
branch: dev
---

# C++ dict key order with a high byte and prefix pairs

**Task**: AZ-3162_cpp_dict_key_order_high_byte
**Name**: C++ dict key order with a high byte and prefix pairs
**Description**: Host tests pin keys_ascending on 0x80 vs 0x7f and on prefix pairs, through pack.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `cpp/tests/core/dict_order_host_tests.cpp`
**Tracker**: AZ-3162
**Epic**: AZ-2645

## Problem

`keys_ascending` (`cpp/src/core/pack.cpp`, an inline byte loop since AZ-3151) has no test on a byte at or above 0x80 against one below it, nor on a prefix pair; a signed compare or a length-first compare would pass today's tests.

## Outcome

- Packing a dict with raw string keys: ascending packs, descending and equal are refused, for the high-byte pair and the prefix pair.

## Scope

### Included
- Test code in the files named under Component.

### Excluded
- Any product code, `fixtures/` in the real tree, the other packages' loaders.

## Acceptance Criteria

**AC-5: High byte** — Given raw string keys `0x7f` then `0x80`, When packed, Then it packs; given `0x80` then `0x7f`, Then it is refused with the dict's error.

**AC-6: Prefix pair** — Given keys `"a"` then `"ab"`, Then it packs; `"ab"` then `"a"`, and an equal pair, are refused.

**AC-7: Sensitivity** — Given a scratch copy of `keys_ascending` with a signed compare, and one with a length-first compare, When the new test runs, Then it fails for each; on the real source it passes; no file under `cpp/src` or `cpp/include` changes and the arm stage figures are unchanged.

## Non-Functional Requirements

**Compatibility**: test code only; Cortex-M4F flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5, AC-6 | host test, 5 packs/refusals | pass on the real source |
| AC-7 | scratch copy of pack.cpp with each broken compare | new test fails for each |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |

## Outcome of loop 58

AC-5, AC-6 and AC-7 met. `pack_orders_keys_as_unsigned_bytes` packs raw string keys through `packbin::pack` (7 checks: `7f` then `c2 80`, prefix pair `a` then `ab`, longer-first `ab` then `b`, and the reverse and equal pairs refused with `BadValue`). A scratch `pack.cpp` with a signed compare fails the two high-byte checks; one with a length-first compare fails `ab then b`. Real source passes on the Mac host and in `gcc:16`; no file under `cpp/src` or `cpp/include` changed.
