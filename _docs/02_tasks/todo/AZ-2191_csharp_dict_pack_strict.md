# C# dictionary-row pack refuses values that do not fit their field

**Task**: AZ-2191_csharp_dict_pack_strict
**Name**: C# strict numeric pack for dictionary rows
**Description**: `Pack` of a dictionary row throws `ArgumentException` naming the member for an integer that does not fit its width, a fraction, a bool or string for an integer, a string or bool for a float, and an f32 overflow, instead of a bare `OverflowException`, rounding or coercion.
**Complexity**: 1 point
**Dependencies**: AZ-2088_csharp_pack_fails_loudly (loud pack, `ArgumentException` for pack failures)
**Component**: csharp
**Tracker**: AZ-2191
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X9, C#), owner scope A on 2026-10-05. Model: TypeScript AZ-2084_typescript_int_range.

A dictionary row holds boxed values of any type, and the number fields convert them with the .NET converters:

| Field | Value | Today | Correct |
|-------|-------|-------|---------|
| u8 | 300 | bare `OverflowException`, no member name | `ArgumentException` naming the member |
| integer | 1.5 | packs `01 02` (rounds) | refuse |
| integer | `true` | packs as 1 | refuse |
| integer | `"5"` | packs as 5 | refuse |
| f32 | 1e39 | packs as +infinity | refuse |
| f64 | `"1.5"` or `true` | accepted | refuse |

Typed rows cannot hold these values, so only the dictionary path is affected. Values that unpack returns for u8 to u32 and i8 to i32 are whole-number doubles in C# (AZ-2116 may change that), and a dictionary built from JSON holds doubles or longs; those must keep packing.

## Outcome

- Every integer and float field accepts only a number that fits it; anything else throws `ArgumentException` naming the member and the kind (for example `A: 300 does not fit in u8`).
- Valid rows give the same bytes as today. Typed rows are unchanged.

## Scope

### Included
- Integer kinds u8 to u64 and i8 to i64, and floats f32 and f64, including `Be()`, and fields under `Flags`, `When`, `Repeat`, `Times`, list and dict elements.
- Pack of a dictionary row (and the typed path, which goes through the same values).

### Excluded
- `u2`, `bits`, `packed`, `sized`, `bytes`, `utf8`, counts (see Flagged concerns).
- Unpack; other packages (Java AZ-2190, Python AZ-2192).
- A new error type: `ArgumentException` stays.

## Acceptance Criteria

**AC-1: An integer that does not fit is refused**
Given integer fields and values: u8 300, u8 -1, i8 200, u16 65536, i16 -32769, u32 4294967296, i32 3000000000, i64 given 2^63 (a `ulong`), u64 given -1
When the row is packed
Then `ArgumentException` names the member and the kind, and no bytes are returned.

**AC-2: A fraction, bool or string is refused for an integer**
Given a u8 field with 1.5, `NaN`, `true` and `"5"`
When the row is packed
Then each throws `ArgumentException` naming the member (today 1.5 packs `01 02`, `true` packs 1, `"5"` packs 5).

**AC-3: Floats accept only numbers, and f32 does not overflow**
Given an f64 field with `"1.5"` and `true`, an f32 field with 1e39, then f32 with +infinity and -infinity, and f64 given 2 as an `int`, 1.5 as a `float` and 1.5 as a `double`
When the rows are packed
Then the string, the bool and 1e39 throw `ArgumentException` naming the member; infinities (`0000807f`, `000080ff`) and NaN are written; every numeric type packs.

**AC-4: Valid values are unchanged**
Given range edges (u8 0 and 255, i8 -128 and 127, u16 65535, i16 -32768, u32 4294967295, i32 -2147483648, u64 `ulong.MaxValue`, i64 `long.MinValue`), whole numbers held as `double` or `long` (5.0 into a u8), the golden row and the route fixture
When they are packed
Then the bytes equal today's bytes (golden `4001000065cd1d00a3e1110100`, route `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`).

**AC-5: A row from unpack packs again**
Given a row read by unpack, with whole-number doubles for narrow integers and exact `ulong` / `long` for 64-bit fields
When it is packed
Then the bytes equal the original packet.

## Non-Functional Requirements

**Performance**
- Project AC-10 (100 000 round trips) stays within its limit; the check is a few comparisons per field.

**Compatibility**
- No wire change; only values that were wrapped, rounded, coerced or threw a bare `OverflowException` change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each row of the table above | `ArgumentException` naming member and kind |
| AC-2 | u8 with 1.5, `NaN`, `true`, `"5"` | `ArgumentException` |
| AC-3 | f64 `"1.5"`, `true`; f32 1e39, infinities, NaN; numeric types | throw / written / written / packs |
| AC-4 | range edges, `double` 5.0, fixtures | bytes unchanged |
| AC-5 | read a packet, pack the row | equal bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `fixtures/golden.hex`, route fixture, C# handoff driver cases (dictionary rows) | pack, then the other languages unpack | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: C# keeps its own check; no shared code with TypeScript.
- `ArgumentException` stays the pack error type; no public API change.
- Wire bytes in the ACs come from the ticket probes and the TypeScript model; the worker re-derives them from a real run (NaN bytes depend on the runtime's NaN pattern, so the test pins that NaN is written, not its bytes).

## Risks & Mitigation

**Risk 1: A caller relied on rounding or coercion**
- *Risk*: a fraction, `true` or `"5"` into an integer now throws.
- *Mitigation*: that is the defect; README upgrade note. Whole-number doubles and longs keep working.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `u2` slots and `bits` / `packed` items also convert with rounding (a 1.5 in a `u2` slot packs as 2); not in the ticket text, so left out. Decide whether to include them here or in a follow-up | owner | open | Medium |
| Whole-number doubles are accepted for integer fields because unpack and JSON produce them; AZ-2116 (exact integer types) may change what unpack returns | AZ-2116 | open | Low |
| Error type and label for pack failures stay as they are (C15) | docs / C15 | accepted-risk | Low |
