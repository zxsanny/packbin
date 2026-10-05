# TypeScript pack refuses values that do not fit their field

**Task**: 15_typescript_int_range
**Name**: TypeScript numeric range check on pack
**Description**: `BinaryPacker.pack` and `PackSession.pack` throw `RangeError` naming the field instead of silently wrapping, truncating or coercing a number that does not fit its integer or float field.
**Complexity**: 2 points
**Dependencies**: 11_typescript_bool_flag_limit (same walker pack cases; land in order)
**Component**: typescript
**Tracker**: pending
**Epic**: AZ-2069

## Problem

Integer fields are written with `DataView.setUint8/16/32`, `setInt8/16/32` and `setBig(U)Int64` (`kinds.ts:216-240`). These wrap modulo 2^n and truncate fractions with no error. `asNumber` (`kinds.ts:210-214`) accepts any `number` or `bigint`. Float fields use `Number(values[f.name])` (`walker.ts:78`), which coerces strings, and `setFloat32` turns large finite values into `Infinity` (`kinds.ts:242-249`).

This contradicts `architecture.md` §4 ("pack refuses an integer that does not fit") and the TS component description (`BinaryPacker.pack` error "integer does not fit"). Python raises `OverflowError("0: 300 does not fit in u8")` / `TypeError("expected int, got float")` (`_pack.py:108-115`).

Reproduced on `d108141` with `scheme(1, <field>(0, x=>x.a))`:

| Field | Value | Bytes today (after type byte `01`) | Correct |
|-------|-------|-------------------------------------|---------|
| `u8` | 300 | `2c` | refuse |
| `u8` | −1 | `ff` | refuse |
| `u8` | 1.7 | `01` | refuse |
| `u8` | `NaN` | `00` | refuse |
| `i8` | 200 | `c8` | refuse |
| `u16` | 65536 | `0000` | refuse |
| `i16` | −32769 | `ff7f` | refuse |
| `u32` | 2^32 | `00000000` | refuse |
| `i32` | 3 000 000 000 | `005ed0b2` | refuse |
| `i64` | `2n**63n` | `0000000000000080` | refuse |
| `u64` | `-1n` | `ffffffffffffffff` | refuse |
| `u64` | `2**53 + 1` (number) | `0000000000002000` (= 2^53, precision lost) | refuse (not a safe integer) |
| `u64` | `2**60` (number, exact) | `0000000000000010` | refuse (not a safe integer; pass `2n**60n`) |
| `u8` | `5n` | `05` | accept |
| `u8` | `true` | throws `RangeError: expected number` (no field name) | refuse, naming the field |
| `f32` | `1e39` | `0000807f` (+Infinity) | refuse |
| `f64` | `"1.5"` | `000000000000f83f` | refuse (not a number) |
| `f64` | `"abc"` | `000000000000f87f` (NaN) | refuse |

## Outcome

- Every integer field accepts only an integer within its range: a safe-integer `number` or a `bigint` for any width; an unsafe `number` is refused for 64-bit fields. Anything else throws `RangeError` whose message names the member and the kind (e.g. `a: 300 does not fit in u8`).
- Float fields accept only `number`. `f32` refuses a finite value that would become infinity. `NaN` and `±Infinity` given explicitly are written, as in Python.
- In-range values give the same bytes as today. Golden hex and every fixture are unchanged.
- A row returned by `unpack` (numbers for ≤ 32-bit, `bigint` for 64-bit) packs again without error.

## Scope

### Included
- Integer kinds `u8…i64`, including `be(...)` and fields under flags, `when`, `repeat`, `times`, list/dict elements.
- Float kinds `f32`, `f64`.
- Clear pack and session pack (session pack calls clear pack).

### Excluded
- `u2`, `bits`, `packed`, `sized`, `bytes`, `utf8`: they already validate.
- Unpack (no change).
- Python's acceptance of numeric strings for floats (`float("1.5")`). See the flagged concern.

## Acceptance Criteria

**AC-1: out-of-range integers are refused**
Given each integer row in the table marked "refuse"
When it is packed
Then `RangeError` is thrown, naming the member and the kind, and no bytes are returned

**AC-2: in-range integers are unchanged**
Given `u8` 0 and 255, `i8` −128 and 127, `u16` 65535, `i16` −32768, `u32` 4294967295, `i32` −2147483648, `u64` `2n**64n - 1n`, `i64` `-(2n**63n)`, `u8` `5n`
When packed
Then the bytes equal today's bytes for the same values (e.g. `u16` 65535 → `ffff`)

**AC-3: fractional and non-numeric values are refused**
Given `u8` 1.7, `u8` `NaN`, `u8` `true`, `f64` `"1.5"`, `f64` `"abc"`
When packed
Then each throws `RangeError` naming the member

**AC-4: f32 overflow is refused, explicit specials allowed**
Given `f32` 1e39, then `f32` `Infinity`, then `f32` `NaN`
When packed
Then the first throws `RangeError`, and the other two write `0000807f` and `0000c07f`

**AC-5: unpacked rows pack again**
Given a scheme with `u64` and `i64` fields
When `pack(unpack(pack(row)))` runs
Then the second pack equals the first

**AC-6: fixtures unchanged**
Given the golden row, the route fixture and the language-pair handoff rows
When packed
Then the bytes are unchanged (`4001000065cd1d00a3e1110100` for the golden row)

## Non-Functional Requirements

**Performance**
- The AC-10 loop (100 000 round trips) stays ≤ 1 s. The check is a few comparisons per field.

**Compatibility**
- Browser-safe `src`. `BigInt` and `Number.isSafeInteger` are standard.

## Unit Tests

Write first; each "refuse" row must fail on `d108141`.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `integer out of range throws` | each "refuse" integer row | `RangeError` mentioning `a` and the kind |
| AC-2 | `integer range edges pack as before` | edge values | unchanged hex |
| AC-3 | `fraction and non-number throw` | 1.7, NaN, true, "1.5", "abc" | `RangeError` |
| AC-4 | `f32 overflow throws, specials pass` | 1e39 / Infinity / NaN | throw / `0000807f` / `0000c07f` |
| AC-5 | `64-bit unpacked row packs again` | `u64` `2n**60n`, `i64` −5n | equal bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/golden.hex`, route fixture | pack | unchanged | project AC-1/3 |
| AC-6 | language-pair `user`, `nested`, `session` handoffs (TS producer) | pack then the consumer unpacks | unchanged hex, consumers pass | project AC-3 |
| — | `fixtures/hostile/` (task 01) | unpack | unchanged by this task | Reliability |

## Constraints

- ADR-001: TS only.
- Browser-safe: no `node:` imports, `Buffer`, `process` in `src`.
- Errors are `RangeError` (the existing pack error type), thrown before anything is returned.

## Risks & Mitigation

**Risk 1: Callers relied on wrapping**
- *Risk*: A caller passing `-1` to a `u16` to mean `0xffff` now gets an error.
- *Mitigation*: That is the bug the architecture names. Note it in the v0.2.0 release notes.

**Risk 2: 64-bit numbers above 2^53**
- *Risk*: Callers passing large `number`s to `u64` now get an error.
- *Mitigation*: Those values were already corrupted (2^53 + 1 → 2^53). The message says to pass a `bigint`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Python accepts numeric strings for floats (`float("1.5")`); TS will refuse them. This is a small cross-language difference in pack input, not in bytes | C15 / Python follow-up | open | Low |
| Wire bytes do not change; only inputs that were silently corrupted now throw. Needs a release note | release owner | open | Low |
