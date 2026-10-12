---
loop: 21
branch: dev
---

# C# unpack returns exact integer types, then integer fields refuse whole-number floats on pack

**Task**: AZ-2373_csharp_exact_integer_types_unpack
**Name**: C# exact integer types from unpack
**Description**: C# unpack returns exact `byte`/`ushort`/`uint`/`sbyte`/`short`/`int` values for narrow integer fields (finishing AZ-2116), and pack then refuses a whole-number float (5.0) for an integer field, as Java, Python and Rust do.
**Complexity**: 5 points
**Dependencies**: AZ-2116, AZ-2358 (partial, loop 20)
**Component**: csharp
**Tracker**: AZ-2373
**Epic**: AZ-2069

## Problem

Owner decision 6 of loop 20 (assessment U5, option A) and the owner's answer on the AZ-2358 partial result (2026-10-11, option A: document now, spec the fix for loop 21). C# unpack boxes u8..u32 and i8..i32 as `double` (`ReadNarrowScalar`; AZ-2116 left exact types undone), and dictionary repack of unpacked `Values` is a tested contract, so AZ-2358 refuses whole floats only for `eq` values and `u2`/`bits`/`packed` slots. Refusing them for integer fields failed 37 existing tests in 15 files (`StrictNumberTests.Pack_RowReadByUnpack_PacksAgainToTheSameBytes`, `DictRepackTests` Ac1/Ac2, `RoundValueTests`, `LoneRoundValueTests`, `LoneDictRoundTests.Ac3_Pack_UnpackedRoundsOfDictionaries_RepackToTheSameBytes`, `BorrowedCountTests.Route_MatchesFixtureAndRejectsAShortTail`, and others); none was weakened.

## Outcome

- `UnpackResult.Values` holds exact integer types for narrow integer fields; the README is updated (it documents doubles today).
- Pack refuses a `double`/`float`/`decimal` with a whole value for an integer field, naming the field; `f32`/`f64` still take whole floats.
- Unpack then repack of the same dictionary row gives the same bytes.

## Acceptance Criteria

**AC-1: exact types**
Given a packet with `u8`, `u16`, `u32`, `i8`, `i16`, `i32` fields
When unpacked into a dictionary row
Then the values are `byte`, `ushort`, `uint`, `sbyte`, `short`, `int`

**AC-2: whole floats refused**
Given a `u8` field with `5.0`
When packed (typed and dictionary rows)
Then refused naming the field; `f64` with `5.0` still packs

**AC-3: repack**
Given every existing unpack-then-repack test
When run
Then all pass with the same bytes (tests that asserted doubles are changed to the exact types, with a line in the batch report for each)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | exact types per kind | types as listed |
| AC-2 | whole floats on pack | refused / f64 packs |
| AC-3 | the 37 listed tests | pass |

## Constraints

- A public change (`UnpackResult.Values` types): README and upgrade note; wire bytes unchanged.
- Keep each file at or under 500 lines.
