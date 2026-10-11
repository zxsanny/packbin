# Blackbox Tests 9: C# typed rows and rings, loop 18 (FT-X-17 to FT-X-21)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-X-17: C# refuses a collection member that cannot hold its field when the scheme is built

**Summary**: A C# typed row member whose element type cannot hold its field, or whose collection type is not supported, fails `new Scheme<T>` with `ArgumentException` naming the member (loop 18, AZ-2305).
**Traces to**: AZ-2305 AC-1, AZ-2305 AC-2, AZ-2305 AC-4
**Category**: Errors

**Preconditions**:
- C# as built in loop 18 (wave 1); net10.0 and netstandard2.0

**Input data**: `List<int>`, `int[]` and `Dictionary<string,int>` members for a `u32` list or dict field; `List<byte>` for a `u16` field; `Stack<int>`, `HashSet<int>`, `IEnumerable<int>` and a subclass of `List<E>` for a list field; a dictionary with `int` keys for a dict field; controls: `List<long>` for `u32`, every integer member that holds the field's whole range, `double` for `f32`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build each refused scheme | `ArgumentException` naming the member and the element type |
| 2 | build each control, then pack and unpack the existing suite schemes, the README example and the golden | the scheme builds; bytes and results unchanged |

**Expected outcome**: step 1 is an `ArgumentException` in every refused shape; step 2 is unchanged on net10.0 and netstandard2.0. The rule: an integer member must contain the field's whole range; `float`, `double` and `decimal` members are accepted; `IList<E>`, `IList`, `IDictionary<string,E>` and `IDictionary` are accepted; the check is skipped for list and dict fields inside a round. Not specified: whether `ICollection<E>` and `IReadOnlyList<E>` should be accepted (review C4, open owner question).
**Max execution time**: 1s

### FT-X-18: A non-null nested row with all members null is present

**Summary**: A non-null typed nested row object under a `Flags` group sets the group's bit even when every member is null, and pack then fails naming the first missing member; a null nested row stays absent (loop 18, AZ-2306).
**Traces to**: AZ-2306 AC-1, AZ-2306 AC-2, AZ-2306 AC-3
**Category**: Errors

**Preconditions**:
- C# as built in loop 18 (wave 1)

**Input data**: `Flags(0, Group(Leaf: u8 A, u8 B))` with `Leaf = new Leaf()` (all members null), `Leaf = null`; the depth-2 scheme `Flags(0, Group(Mid: u8 M, Group(Leaf: u8 A)))` with `Mid = new Mid()`, `Mid = {M=4, Leaf = new Leaf()}`, `Mid = {M=4, Leaf.A=6}`, `Mid = null`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the all-null objects (depth 1 and 2) | `ArgumentException` naming `A`, `M` and `A`; no bytes |
| 2 | pack the null nested rows | `0100`, the bit clear |
| 3 | pack the filled depth-2 row and unpack it | `01010406`; `Mid.Leaf.A` is 6 |

**Expected outcome**: step 1 is an `ArgumentException` naming the first missing member; step 2 is `0100` for both schemes; step 3 gives `01010406` and the same row.
**Max execution time**: 1s

### FT-X-19: A C# `Flags` list or dict element, and C# in the three element rings

**Summary**: A `Flags` container as a direct list or dict element packs and unpacks in C# with the TypeScript bytes, and C# takes part in the `listgroup`, `dictgroup` and `listflags` cross-language rings (loop 18, AZ-2307).
**Traces to**: AZ-2307 AC-1, AZ-2307 AC-2, AZ-2307 AC-3, AZ-2307 AC-4
**Category**: Bytes

**Preconditions**:
- C# as built in loop 18 (wave 1 and the ring files `.github/workflows/language-pair.sh`, `drivers/csharp/HandoffElements.cs`, `ring-wiring.test.sh`); the rings run in the one total test run (Docker or all six runtimes)

**Input data**: the element `flags{ u8 a (bit 0), u16 b (bit 1) }`; the list `[{a:1}, {}, {b:2}]`; the dict `{y: {b:2}, x: {a:1}}`; the ring hex `listgroup` `01020001020304`, `dictgroup` `01020001007801020100790304`, `listflags` `010300010100020200`, and their short forms `010200010203`, `010200010078010201007903`, `0103000101000202`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the list and the dict in C# dictionary mode and in typed mode | `010300010100020200` and `0102000100780101010079020200`, the TypeScript bytes; no `KeyNotFoundException` |
| 2 | unpack both hex strings | one row per element holding only what was read |
| 3 | `language-pair.sh` runs the rings (chain TypeScript, Python, Java, C#, TypeScript) | C# packs for and unpacks from its neighbour in each of the three rings, and refuses the three short packets |
| 4 | `ring-wiring.test.sh` with one C# handoff line, a driver command or the C# entry of the short-packet loop removed | the wiring test fails naming what is missing |

**Expected outcome**: step 1 gives the hex above; step 3 passes for `listgroup`, `dictgroup` and `listflags`; step 4 fails for each removal; the existing C# suite is unchanged on net10.0 and netstandard2.0. Not specified: the ring is a chain, not all pairs (review C10, open owner question: all pairs would add 18 handoffs).
**Max execution time**: 1s (steps 1, 2 and 4); the rings run in the CI ring job

### FT-X-20: C# `u2` slots, `bits` and `packed` items take whole numbers that fit

**Summary**: A C# `u2` slot, `bits` item or `packed` item accepts only a whole number that fits and refuses anything else with `ArgumentException` naming the member, as every other integer field does (loop 18, AZ-2309).
**Traces to**: AZ-2309 AC-1, AZ-2309 AC-2, AZ-2309 AC-3, AZ-2309 AC-4
**Category**: Errors

**Preconditions**:
- C# as built in loop 18 (wave 1)

**Input data**: `u2` of two slots; `u8 n` then `bits` (count n); `packed(1)` and `packed(2)` items; values: fractions (`1.5` in a `u2` slot, `2.5` and `0.5` in `bits`, `0.5` in `packed`); out of range (`4`, `-1`, `4.0` in `u2`; `2` in a `bits` or `packed(1)` item; `4` and `-1` in `packed(2)`; NaN, infinity); `true`, `"1"`, `'a'`, `DayOfWeek.Monday`, `new object()`, `null`; valid values `u2` 0, 3, 3.0, 2L, `(byte)1`, `bits` item 1 and 1.0, `packed(1)` item 1L, `packed(2)` item 3 and 3.0

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each fraction, each out-of-range value and each wrong-typed value | `ArgumentException` naming the member; no bytes |
| 2 | pack the valid values | `u2`: `0100`, `0103`, `0103`, `0102`, `0101`; `bits` item 1: `010202`; `packed(1)` item 1: `010202`; `packed(2)` item 3: `01020c` |
| 3 | pack a fraction inside `Flags`, a `Repeat` and a list element; pack the golden and route fixtures; run the 100000 round trips (NFT-PERF-01) | the fraction is refused; the fixtures and the timing are unchanged |

**Expected outcome**: step 1 is an `ArgumentException` in every case (a null item used to pack as 0 and is now refused); step 2 gives the hex above (a whole number held as `double` or `long` equals the integer bytes); step 3 as stated. Not specified: whether the other five packages round fractions in `u2` slots, `bits` and `packed` items (not probed; carried to the next loop, batch 1 discovery 13).
**Max execution time**: 1s

### FT-X-21: C# dictionary pack repacks what `Read` returned, and an int for `Bytes` or `Sized` is refused

**Summary**: The rows `Read` returns for a list or dict of group elements pack again to the original bytes, and an `int` given for a `Bytes` or `Sized` name is an `ArgumentException` naming the member, in and outside a round (loop 18, AZ-2310).
**Traces to**: AZ-2310 AC-1, AZ-2310 AC-2, AZ-2310 AC-3, AZ-2310 AC-4
**Category**: Bytes

**Preconditions**:
- C# as built in loop 18 (wave 1)

**Input data**: a list of group elements `u8 a, u8 b` (anchored and unanchored) and a dict of the same, with the packet `01 0200 0102 0304` (the `listgroup` ring packet) and its dict form; groups holding a string and flags; about 360 000 random packets over six schemes; the scheme `u8 n; bytes raw; sized data` with an `int` for `raw` and for `data`, outside a round and inside a `times` round

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | `Read` the packet in dictionary mode, pass the row to `Pack` | the original bytes `01020001020304`; no `'A' has no value` |
| 2 | unpack each random packet, then repack | the original packet (list schemes), or a stable second repack (dict schemes, whose keys are re-sorted); a packet that fails unpack fails in the same way |
| 3 | pack an `int` for a `Bytes` name and for a `Sized` name | `ArgumentException` naming the member; no `InvalidCastException` |
| 4 | pack `byte[]` for both; run the existing suite on both targets | the bytes of today; results unchanged |

**Expected outcome**: step 1 gives the original hex; step 2 holds for every random packet; step 3 is an `ArgumentException` in and outside a round; step 4 is unchanged on net10.0 and netstandard2.0.
**Max execution time**: 30s (the random repack)
