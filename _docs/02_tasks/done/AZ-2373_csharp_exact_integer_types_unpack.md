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

Owner decision 6 of loop 20 (assessment U5, option A) and the owner's answer on the AZ-2358 partial result (2026-10-11, option A: document now, spec the fix for loop 21). C# unpack boxes u8..u32 and i8..i32 as `double` (`ReadNarrowScalar`; AZ-2116 left exact types undone), and dictionary repack of unpacked `Values` is a tested contract, so AZ-2358 refuses whole floats only for `eq` values and `u2`/`bits`/`packed` slots. Refusing them for integer fields fails 7 existing test cases once unpack returns exact types (five `StrictNumberTests.Pack_NumberThatFits_PacksAsBefore` rows, `SchemeOwnershipTests.Scheme_SharedTimesFieldAcrossTwoSchemes_KeepsItsOwnCount` and `PackOutputBudgetTests.Ac2_Pack_ElementsThatEachHoldATimes_AreRefusedAtTheDefaultAndPackWithARaisedBudget`; see Loop 21 result). The loop 20 estimate was 37 existing tests in 15 files; none was weakened.

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
| AC-3 | the existing unpack-then-repack tests (7 cases changed, see Loop 21 result) | pass |

## Constraints

- A public change (`UnpackResult.Values` types): README and upgrade note; wire bytes unchanged.
- Keep each file at or under 500 lines.

## Loop 21 result

Implemented in loop 21 (commit 3acc589, `csharp/`): `UnpackResult.Values` holds `byte`, `sbyte`, `ushort`, `short`, `uint`, `int`, `ulong` and `long` for the integer fields (`f32` stays a `double`), and `Walker.WholeNumber` refuses a `float`, `double` or `decimal`, whole or not, for an integer field (`U8: 5 is a Double; u8 takes an integer type, not a float, double or decimal (f32 and f64 take them)`); `f32` and `f64` still take whole floats. Tests: `ExactIntegerTypeTests` (AC-1, AC-2, AC-3), `StrictNumberTests` (new `WholeFloats` theory).

The loop 20 estimate of 37 existing tests in 15 files was 7 failing cases in the implementation (step 11 report: "the 37-test claim of the AZ-2373 spec was 7 failing cases"), all changed to the exact types (no test was weakened): five rows of `StrictNumberTests.Pack_NumberThatFits_PacksAsBefore` that packed whole floats (`U8` 5.0, `U32` 4294967295.0, `I16` -2.0f, `U64` 18446744073709549568.0, `U8` 5m), `SchemeOwnershipTests.Scheme_SharedTimesFieldAcrossTwoSchemes_KeepsItsOwnCount` (asserted doubles) and `PackOutputBudgetTests.Ac2_Pack_ElementsThatEachHoldATimes_AreRefusedAtTheDefaultAndPackWithARaisedBudget` (asserted `65_535.0`). The other tests named in the Problem section pass unchanged, because unpack now returns the types that pack accepts. `LoneDictRoundTests` and `NestedRoundTests` also changed, for AZ-2389 and not for this task.

Open (review finding 1, owner row U12): a `List<double>`, `List<float>` or `List<decimal>` member for an integer `List` builds and unpacks, but pack refuses its items. README: Integers, the loop 21 notes and the Limits list.
