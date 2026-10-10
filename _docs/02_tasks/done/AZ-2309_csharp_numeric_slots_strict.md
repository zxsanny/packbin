---
loop: 18
branch: dev
---

# C# u2 slots, bits and packed items follow the strict numeric rule

**Task**: AZ-2309_csharp_numeric_slots_strict
**Name**: C# strict numeric slots
**Description**: `u2` slots, `bits` items and `packed` items accept only whole numbers that fit, and refuse anything else with `ArgumentException` naming the member, like every other integer field since AZ-2191.
**Complexity**: 1 point
**Dependencies**: AZ-2191_csharp_dict_pack_strict (done)
**Component**: csharp
**Tracker**: AZ-2309
**Epic**: AZ-2069

## Problem

Owner decision 8 of loop 18 (2026-10-10, option A; assessment E11). AZ-2191 left three slot kinds out: a `1.5` in a `u2` slot packs as 2, and `bits` and `packed` items convert with rounding. One rule for every numeric slot.

## Outcome

- A value that is not a whole number, or does not fit the slot, is refused with the member named; valid values and wire bytes are unchanged.

## Scope

### Included
- C# dictionary and typed pack for `u2` slots, `bits` items and `packed` items, including inside `Flags`, `When`, `Repeat`, `Times` and list or dict elements.

### Excluded
- Unpack; other packages (their rules are separate specs).

## Acceptance Criteria

**AC-1: a fraction is refused in a slot**
Given a `u2` slot with 1.5, a `bits` item with 2.5 and a `packed` item with 0.5
When the row is packed
Then each throws `ArgumentException` naming the member, and no bytes are returned

**AC-2: a value that does not fit is refused**
Given a `u2` slot with 4 or -1, and `bits`/`packed` items above their width
When packed
Then `ArgumentException` names the member (use the existing range rule of each kind)

**AC-3: bool, string, char, enum and object are refused**
Given the same slots with `true`, `"1"`, `'a'`, a `DayOfWeek` and an `object`
When packed
Then each throws `ArgumentException` naming the member (decision 7: these stay refused)

**AC-4: valid values unchanged**
Given range edges and whole numbers held as `double` or `long`
When packed
Then bytes equal today's bytes; golden and route fixtures unchanged

## Non-Functional Requirements

**Performance**
- Project AC-10 (100 000 round trips) stays within its limit.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | fractions in each slot kind | `ArgumentException` |
| AC-2 | out-of-range values | `ArgumentException` |
| AC-3 | wrong types | `ArgumentException` |
| AC-4 | edges, fixtures | bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | golden and route | pack | unchanged | AC-10 |

## Constraints

- Files stay at or under 500 lines; `Walker.Numbers.cs` is the existing home of the rule.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Whether other packages round in slots is not probed here; the batch report records what C# does and the next handoff gets the other packages if they differ | coordinator | open | Low |

## Loop 18 result (2026-10-10)

Done in loop 18 wave 1 (csharp). `TrySlot` in `Walker.Numbers.cs`: `u2` slots, `bits` and `packed(1)`/`packed(2)` items refuse fractions, out-of-range, bool, string, char, enum, object, null (a null item used to pack as 0). `StrictSlotTests`. Other packages not probed.
