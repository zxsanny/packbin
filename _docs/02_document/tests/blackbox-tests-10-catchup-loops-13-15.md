# Blackbox Tests 10: Catch-up for loops 13 to 17 (FT-X-22, FT-X-23)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). These two scenarios were written in loop 19 (step 12) for specs that closed in loops 13 to 17 and had no row. Test names were read from the package test directories; the expected values come from the task specs in `_docs/02_tasks/done/`.

### FT-X-22: C# pack fails loudly instead of returning a packet its reader cannot read

**Summary**: A C# row with a missing required value, a short `repeat` or `times` list, a foreign row type, an integer that does not fit, or a fraction, bool or string for an integer field fails with `ArgumentException` naming the member; the golden and route fixtures and every row that packed before keep their bytes (loop 13, AZ-2088; loop 17, AZ-2191).
**Traces to**: AZ-2088 AC-1, AZ-2088 AC-2, AZ-2088 AC-3, AZ-2088 AC-4, AZ-2088 AC-5, AZ-2088 AC-6, AZ-2088 AC-7, AZ-2088 AC-8, AZ-2088 AC-9, AZ-2191 AC-1, AZ-2191 AC-2, AZ-2191 AC-3, AZ-2191 AC-4, AZ-2191 AC-5
**Category**: Errors

**Preconditions**:
- C# as built in loops 13 and 17 (net10.0 and netstandard2.0)

**Input data**: `U16 Heading` (`ushort?`, not in flags) with `{ Tail = 7 }`; `Repeat(0, I32 Lat, I32 Lon)` with `Lat = [1,2]`, `Lon = [3]`; `Times` with `N = 2`, `Lat = [10]`; a `List`, `Dict` or `Sized` member that is `null`; a `U16` field declared for another row type; `F64 F` with a `When(1, Eq(0, 1.0), U8 B)` and `F` = NaN, +infinity, 1e30, 1.0; a `Field[]` replaced after the scheme was built; one `Condition.Eq` shared by two schemes. Numbers: u8 300 and -1, i8 200, u16 65536, i16 -32769, u32 4294967296, i32 3000000000, i64 given a `ulong` 2^63, u64 given -1; a u8 given 1.5, NaN, `true`, `"5"`; an f64 given `"1.5"` and `true`; an f32 given 1e39, +infinity, -infinity; range edges and whole numbers held as `double` or `long`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the rows with a missing value, a short or long list, an absent list, dict or sized member | `ArgumentException` naming the member (or the short list); no `KeyNotFoundException`; no bytes |
| 2 | build `Scheme<NullRow>` with a field declared for `BoolRow` | `ArgumentException` naming both row types; no scheme is built |
| 3 | pack and unpack the four float `when` rows; build a scheme from a `Field[]` and replace an element; pack with one condition shared by two schemes | no exception, only `F` = 1.0 writes `B`; the scheme keeps its layout; the shared condition keeps its own target in each scheme |
| 4 | pack each integer that does not fit, each fraction, bool or string for an integer, and the three bad float values | `ArgumentException` naming the member and the kind |
| 5 | pack the range edges, the whole numbers held as `double` or `long`, the golden row, the route fixture and a row `Read` returned | bytes of today: golden `4001000065cd1d00a3e1110100`, route `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`; the unpacked row packs to the original packet; infinities `0000807f` and `000080ff` are written |

**Expected outcome**: steps 1, 2 and 4 are an `ArgumentException` naming the member (or both row types); step 3 never throws and does not re-bind; step 5 keeps every byte. Left out by AZ-2191 and carried to loop 18: `u2` slots and `bits` or `packed` items (now FT-X-20).
**Max execution time**: 1s

### FT-X-23: Unpack refuses a packet above the round limit, in five packages

**Summary**: C#, TypeScript, Java and Rust (and Python, see the outcome) refuse a `repeat` or `times` that would start round `maxRounds + 1` (default 65 535 rounds) or take the slot total above `maxSlots` (default 4 194 304), with an error value, no handler call and no row; a refused 1 MiB packet costs memory bounded by the limits; C++ has fixed `Array` storage and no limit; the two hostile `limit` cases and the README state the rule (loop 15, AZ-2216 to AZ-2220).
**Traces to**: AZ-2216 AC-1 to AC-11, AZ-2217 AC-1 to AC-11, AZ-2218 AC-1 to AC-11, AZ-2219 AC-1 to AC-13, AZ-2220 AC-1 to AC-7
**Category**: Resource limits

**Preconditions**:
- The packages as built in loop 15; a scheme carries its own limits (`WithLimits` in C#, `withLimits` in TypeScript and Java, `with_limits` in Rust and Python), and a limit left out takes the default, not the receiver's value

**Input data**: `repeat(u8 k)` with 65 535 and 65 536 one-byte rounds; the same scheme with `maxRounds` 3 and packets `01aabbcc`, `01aabbccdd`; `u8 n; times(count n){ u8 k }` with `maxRounds` 3 and packets `0103090909`, `010409090909`, `0104090909`, `01ff09`, `01030909`; `u32 n; times` with counts 65 535, 65 536 and 4 294 967 295 and the packet `01ffffffff00`; a three-name round with `maxSlots` 6 and packets `010000`, `01000000`, `0100000000`; two `times` fields with `maxSlots` 4 and 3 on `0102aabbccdd`; a 1 MiB packet of zero bytes behind a 37-name `repeat`; limits 0 and -1; the hostile cases `repeat_rounds_over_limit` (`0111223344`) and `times_rounds_over_limit` (`010411223344`)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack 65 535 rounds, then 65 536 rounds, at the default limit | the first is accepted with 65 535 entries; the second is a short-read error (`needed` 0, `left` 1) and the handler is not called |
| 2 | unpack the `maxRounds` 3 packets | `01aabbcc` is accepted; `01aabbccdd` is refused when round 4 would start, with `dd` unread; `times` count 4 with three rounds present is refused before the short read the old code returned; count 255 with one round present keeps today's short read of `k` |
| 3 | unpack the `maxSlots` packets | 2 rounds of 3 slots (exactly 6) are accepted; 3 rounds are refused when round 3 would start; the slot total is shared by the fields of one call (and by list elements in Java) |
| 4 | unpack the 1 MiB packet at the default limits | refused at round 65 536 with the rest unread (C# `GetAllocatedBytesForCurrentThread` under 128 MiB; the old code accepted it) |
| 5 | unpack with a receiver that kept its limits, with a stricter derived scheme, and with two handlers of different limits in one call | each scheme applies its own limits |
| 6 | build a scheme with limits 0 or -1, and with the largest limits | a construction error naming `maxRounds` or `maxSlots` (`ArgumentOutOfRangeException`, `RangeError`, `IllegalArgumentException`, a Rust panic); the largest limits unpack the 65 536-round packet |
| 7 | replay `repeat_rounds_over_limit` and `times_rounds_over_limit` | `too_many` or `bad_value` with `needed` 0 and `left` 1 in the five packages; C++ skips the stage with a printed reason (FT-X-04) |
| 8 | run `check-cases.sh` and `cases.test.sh` on the `limit` stage | a `limit` line with hex `-`, odd hex, a stage typo, an unknown term or a duplicate id is rejected naming `<file>:<line>:` |

**Expected outcome**: steps 1 to 6 give the results above in the four packages of AZ-2216 to AZ-2219 (Python later gained limits of its own, `python/tests/test_round_limits.py` with 23 tests; no done spec names that change, so only step 7 is stated for Python); every pre-existing test is unchanged, including `oversize_count_times` (`01ffffffff00` still gives a short read of the body field, because round 1 starts and round 2 never does); step 7 passes in five packages and is skipped in C++; step 8 is rejected for each corruption. The README "Untrusted input" section and the security report state the rule (AZ-2220 AC-8 and AC-9, owned by the docs and security steps and not read here). Upgrade note: a packet above either limit that unpacked before is refused until the scheme raises the limit.
**Max execution time**: 5s (the 1 MiB packet returns in well under 1 s)
