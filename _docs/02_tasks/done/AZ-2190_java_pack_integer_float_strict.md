# Java pack refuses what does not fit an integer field and bad floats

**Task**: AZ-2190_java_pack_integer_float_strict
**Name**: Java pack range and type check for integers and floats
**Description**: Java pack throws `IllegalArgumentException` naming the member for an integer that does not fit its width (including a `BigInteger` that wraps), a fraction, string or boolean for an integer, a string or boolean for a float, and an `f32` overflow, instead of wrapping, truncating, throwing a bare `ClassCastException` or writing infinity.
**Complexity**: 1 point
**Dependencies**: AZ-2089_java_forward_refs_bool (Java pack path), AZ-2084_typescript_int_range (the model)
**Component**: java
**Tracker**: AZ-2190
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X9, Java), owner scope A on 2026-10-05: not fixed in loop 13, filed as a follow-up.

- `architecture.md`: "pack refuses an integer that does not fit". Java's dynamic-row pack (a `Map` or object row, values typed as `Object`) breaks that for some values. Typed members cannot hold these values.
- Today, read from the code and the assessment probes (the worker replays each on the current code first):

| Field | Value | Today | Wanted |
|-------|-------|-------|--------|
| `i64` | `BigInteger` 2^63 | packs `01 00 00 00 00 00 00 00 80` (wraps to -2^63) | refuse |
| `u8` | `BigInteger` 2^64 + 5 | packs `01 05` (wraps) | refuse |
| `i32` | `BigDecimal` 1.5 | packs the truncated 1 | refuse |
| `f32` | `Double` 1e39 | packs `01 00 00 80 7f` (+infinity) | refuse |
| `f64` | `"1.5"` | `ClassCastException` | refuse, naming the member |
| `f32` | `true` | `ClassCastException` | refuse, naming the member |
| `u8` | `Integer` 300 | `ArithmeticException` naming the member | refuse (`IllegalArgumentException`) |
| `u64` | `Long` -1 | packs `01` + `ff` x 8 | unchanged (see Flagged concerns) |

- Already refused with `IllegalArgumentException` ("expected int, got ..."): a `Double`, `Float`, `String` or `Boolean` for an integer; a negative `Integer`, `Short` or `Byte` for `u64` throws `ArithmeticException`.
- Java unpack returns a `u64` as a signed `Long`, so a `u64` read from the wire above 2^63 is a negative `Long`. Refusing it would stop a row read from the wire packing back to the same bytes.

## Outcome

- A value is written only if it is a whole number inside its integer field's range; `BigInteger` and other numeric types are range-checked before narrowing.
- Float fields take numbers only; `f32` refuses a finite value that would become infinity. `NaN` and `+/-Infinity` given explicitly are still written.
- Every refusal is an `IllegalArgumentException` that names the member. Valid rows give the same bytes as today.

## Scope

### Included
- All integer kinds `u8..i64` (including `be(...)`), `f32`, `f64`, anywhere a scalar is packed: top level, under `flags` / `when`, in `repeat` / `times` rounds, in list and dict elements.
- Clear pack and session pack (session pack calls clear pack).

### Excluded
- `u2`, `bits`, `packed`, `sized`, `bytes`, `utf8`: they already validate.
- Unpack. `f32` underflow (a tiny finite value becoming 0).
- Accepting a `BigInteger` for `u64` (refused today as a wrong type; unchanged).
- C# (AZ-2191) and Python (AZ-2192) have the same class of gap and are filed separately.

## Acceptance Criteria

**AC-1: A wrapping `BigInteger` is refused**
Given `i64 a` and `u8 a`, one scheme each
When packed with `BigInteger` 2^63 and `BigInteger` 2^64 + 5
Then each throws `IllegalArgumentException` naming `a`, with no bytes returned; `i64` with `BigInteger` -2^63 still packs `01 00 00 00 00 00 00 00 80`.

**AC-2: Out-of-range integers are refused**
Given one scheme per row: `u8` 300 and -1, `i8` 200, `u16` 65536, `i16` -32769, `u32` 4294967296 (`Long`), `i32` 3000000000 (`Long`)
When packed
Then each throws `IllegalArgumentException` naming the member (today an `ArithmeticException`).

**AC-3: Fractions, strings and booleans are refused for integers**
Given `u8 a`
When packed with 1.7 (`Double`), 1.7 (`Float`), 1.5 (`BigDecimal`), `"5"` and `true`
Then each throws `IllegalArgumentException` naming `a`.

**AC-4: Strings and booleans are refused for floats**
Given `f64 a` and `f32 a`
When packed with `"1.5"`, `"abc"` and `true`
Then each throws `IllegalArgumentException` naming `a`, not `ClassCastException`.

**AC-5: `f32` overflow is refused, explicit specials are written**
Given `f32 a`
When packed with 1e39 (`Double`), then `Infinity`, then `NaN`
Then the first throws `IllegalArgumentException` naming `a`; the other two give `01 00 00 80 7f` and `01 00 00 c0 7f`.

**AC-6: Valid rows are unchanged**
Given `u8` 0 and 255, `i8` -128 and 127, `u16` 65535, `u32` 4294967295 (`Long`), `i32` -2147483648, `i64` `Long.MIN_VALUE`, `u64` `Long` -1, `f32` 3.5, `f64` 1.5, the golden fixture and the route fixture
When packed
Then the bytes equal today's bytes (for example `u16` 65535 gives `01 ff ff`), and a row read by `unpack` packs back to the same bytes.

**AC-7: Session pack refuses the same**
Given an open `PackSession` pair
When `pack` is called with each refused value above
Then it throws as clear pack does, and a valid row packed next is read by the peer.

## Non-Functional Requirements

**Compatibility**
- Valid rows keep their bytes. The exception type of an out-of-range `Integer` or `Long` changes from `ArithmeticException` to `IllegalArgumentException` (the type of every other Java pack failure).

**Reliability**
- Pack returns bytes the peer reads as the same row, or throws (AZ-2088 NFR).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `BigInteger` 2^63 into `i64`; 2^64 + 5 into `u8`; -2^63 into `i64` | two throws; `01 00 00 00 00 00 00 00 80` |
| AC-2 | the seven out-of-range rows | `IllegalArgumentException` naming the member |
| AC-3 | five values into `u8` | `IllegalArgumentException` naming `a` |
| AC-4 | `"1.5"`, `"abc"`, `true` into `f64` and `f32` | `IllegalArgumentException`, not `ClassCastException` |
| AC-5 | 1e39, `Infinity`, `NaN` into `f32` | throws; `01 00 00 80 7f`; `01 00 00 c0 7f` |
| AC-6 | boundary values, golden and route fixtures, unpack then repack of a `u64` above 2^63 | bytes identical to today |
| AC-7 | session pair, refused then valid row | throws; peer reads the valid row |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/golden.hex`, route hex, `language-pair.sh` rings | Java producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- Java keeps its own checks (ADR-001); mirror the TypeScript model of AZ-2084, do not share code.
- Wire bytes in the ACs come from the probes quoted above; the worker re-derives each from a real run before pinning it.
- No public API change.

## Risks & Mitigation

**Risk 1: A caller catches `ArithmeticException` around pack**
- *Risk*: out-of-range `Integer` and `Long` values now throw a different type.
- *Mitigation*: README upgrade note in the next docs pass; the message keeps the member name and the value.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket text asks to refuse `Long` -1 for `u64`. The spec keeps it, because Java unpack returns `u64` values above 2^63 as negative `Long`, so refusing it would break unpack-then-repack. Owner confirms | owner | open | Medium |
| A `BigInteger` in 0..2^64-1 is refused for `u64` as a wrong type today, so a caller has only the `Long` bit pattern; accepting it would be API growth | owner | open | Low |
| Exception type change for out-of-range values (above) | accepted by the ticket text | accepted-risk | Low |

## Owner decision (2026-10-06)

DECIDED, the proposed default: keep `Long -1` for u64 so unpack then repack works; refuse `BigInteger`. The open DECISION rows above are resolved by this section.
