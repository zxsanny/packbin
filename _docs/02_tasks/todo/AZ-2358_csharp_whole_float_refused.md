---
loop: 20
branch: dev
---

# C# refuses a whole-number float (5.0) given for an integer eq value or an integer, u2, bits or packed slot

**Task**: AZ-2358_csharp_whole_float_refused
**Name**: C# whole-number floats refused
**Description**: C# refuses a whole-number float (5.0) given for an integer eq value or an integer, u2, bits or packed slot.
**Complexity**: 1 points
**Dependencies**: AZ-2309, AZ-2338 (done)
**Component**: csharp
**Tracker**: AZ-2358
**Epic**: AZ-2069

## Problem

Owner decision 6 of loop 20 (assessment U5, option A). `5.0` equals 5 in C# and TypeScript and is refused by Java, Python and Rust, for `eq` and for slot values. TypeScript is exempt: JavaScript cannot tell 5.0 from 5 (README states it).

## Outcome

- C# refuses a `double`/`float`/`decimal` value for an integer `eq` at construction and for an integer, `u2`, `bits` or `packed` slot at pack, naming the field, as for a fraction (AZ-2309).
- Float fields (`f32`, `f64`) still take whole floats.

## Acceptance Criteria

**AC-1: eq at construction**
Given `Eq(u8Field, 5.0)`
When the scheme is built
Then refused naming the field

**AC-2: slot at pack**
Given a `u8`, `u2`, `bits` and `packed` slot holding `5.0` / `3.0` / `1.0` (typed and dictionary rows)
When packed
Then refused naming the field; `f64` with 5.0 still packs

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Eq with 5.0 | refused |
| AC-2 | slots with whole floats, f64 control | refused / packs |

## Constraints

- Wire bytes of every accepted row are unchanged.
