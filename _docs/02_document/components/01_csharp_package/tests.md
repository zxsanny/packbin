# Test Specification — C# package

## Acceptance Criteria Traceability

| AC ID | Acceptance Criterion | Test IDs | Coverage |
|-------|---------------------|----------|----------|
| AC-1 | Position pack is the 13-byte hex | IT-01, AT-01 | Covered |
| AC-2 | Unpack returns those fields and 0 motion fields | IT-02, AT-01 | Covered |
| AC-3 | This package's bytes match the shared golden hex | IT-03 | Covered |
| AC-4 | Clear bit adds 0 bytes; flags 0x20 adds 2 | IT-04 | Covered |
| AC-5 | A stored 0 is written | IT-05 | Covered |
| AC-6 | Conditional group adds 0 bytes or its width | IT-06 | Covered |
| AC-7 | Repeat yields one value per group; 1 leftover byte is an error | IT-07 | Covered |
| AC-8 | Short field names field, needed, left, and returns 0 values | IT-08, ST-01 | Covered |
| AC-9 | Trailing bytes are an error and 0 values | IT-09 | Covered |
| AC-10 | 100000 round trips ≤ 1 second on one core | PT-01 | Covered |
| AC-11 | This package's tests run on every push and pull request | AT-02 | Covered |
| AC-12 | A matching tag publishes this package, with 0 manual uploads | AT-03, ST-02 | Covered |
| AC-13 | The first tag includes this package with the other five | AT-03 | Covered |
| AC-14 | A golden mismatch publishes 0 packages, including this one | AT-04 | Covered |
| AC-15 | This package absent from the tagged tree publishes 0 packages | AT-05 | Covered |
| AC-16 | This published package declares MIT | AT-06 | Covered |

## Blackbox Tests

### IT-01: Position pack

**Summary**: `pack` of the position fixture yields the 13-byte golden hex.

**Traces to**: AC-1

**Description**: Call `pack` with type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, and motion flags clear.

**Input data**:
```
type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, motion flags clear
```

**Expected result**:
```
4001000065cd1d00a3e1110100
mismatched bytes: 0
length: 13
```

**Max execution time**: 1s

**Dependencies**: the shared golden fixture file

### IT-02: Position unpack

**Summary**: `unpack` of that hex returns the five fields and 0 motion fields.

**Traces to**: AC-2

**Description**: Call `unpack` on `4001000065cd1d00a3e1110100`.

**Input data**:
```
4001000065cd1d00a3e1110100
```

**Expected result**:
```
type 64, sid 1, latitude 500000000, longitude 300000000, profile 1
motion field count: 0
field mismatches: 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-03: Bytes match the golden hex

**Summary**: This package's position bytes equal the shared fixture. A mismatch fails the seam with the other five languages.

**Traces to**: AC-3

**Description**: Pack the position list and compare to the fixture file. This is the package side of the six-language seam.

**Input data**:
```
the position row in the golden fixture
```

**Expected result**:
```
mismatched bytes: 0
```

**Max execution time**: 1s

**Dependencies**: the shared golden fixture file

### IT-04: Flags width

**Summary**: A clear flags bit adds 0 bytes. Flags 0x20 on a uint16 at bit 5 adds 2 bytes.

**Traces to**: AC-4

**Description**: Pack the same list twice, once with flags 0x00 and once with flags 0x20.

**Input data**:
```
flags 0x00
flags 0x20, bit 5 is uint16
```

**Expected result**:
```
flags 0x00 adds 0 bytes
flags 0x20 adds 2 bytes
```

**Max execution time**: 1s

**Dependencies**: none

### IT-05: A stored zero is written

**Summary**: A present 0 sets the field bit. Absence omits the field and does not substitute 0.

**Traces to**: AC-5

**Description**: Pack a value that includes 0, then pack a value that omits that field.

**Input data**:
```
field present, value 0
field absent
```

**Expected result**:
```
present 0 is written and the bit is set
absence adds 0 bytes and the result does not contain 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-06: Conditional group

**Summary**: A `when` group whose tested field does not match adds 0 bytes. A match adds that group's width.

**Traces to**: AC-6

**Description**: Pack one value that fails the condition and one that matches it.

**Input data**:
```
tested field not equal to the when value
tested field equal to the when value
```

**Expected result**:
```
mismatch adds 0 bytes
match adds exactly the group width
```

**Max execution time**: 1s

**Dependencies**: none

### IT-07: Repeat on a group boundary

**Summary**: A buffer of whole groups unpacks one value per group. One leftover byte is an error and 0 values.

**Traces to**: AC-7

**Description**: Unpack a complete repeated group, then a buffer that ends one byte into the next group.

**Input data**:
```
one complete group
one complete group plus 1 leftover byte
```

**Expected result**:
```
complete group: value count 1
leftover byte: error, value count 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-08: Short field

**Summary**: A buffer that ends inside a field returns an error and 0 values.

**Traces to**: AC-8

**Description**: Unpack a buffer that ends inside a named field.

**Input data**:
```
a buffer shorter than the field width
```

**Expected result**:
```
error names the field, the byte count it needed, and the byte count that remained
value count: 0
```

**Max execution time**: 1s

**Dependencies**: none

### IT-09: Trailing bytes

**Summary**: Bytes left after the field list are an error and 0 values.

**Traces to**: AC-9

**Description**: Unpack a buffer that completes the list and then has 1 extra byte.

**Input data**:
```
a complete field list plus 1 trailing byte
```

**Expected result**:
```
error
value count: 0
```

**Max execution time**: 1s

**Dependencies**: none

## Performance Tests

### PT-01: Position round trips on one core

**Summary**: 100000 pack-then-unpack round trips of the AC-1 fixture finish in ≤ 1 second on one core.

**Traces to**: AC-10

**Load scenario**:
- Concurrent users: 1
- Request rate: 100000 sequential round trips, then stop
- Duration: the loop itself
- Ramp-up: none

**Expected results**:

| Metric | Target | Failure Threshold |
|--------|--------|-------------------|
| Elapsed time of 100000 round trips | ≤ 1 second | > 1 second |
| Error count | 0 | > 0 |
| Throughput | the same loop on one core | a second core is required to meet the bound |
| Latency (p50, p95, p99) | not the bound | this NFR is elapsed time, not a percentile |

**Resource limits**:
- CPU: one core
- Memory: the test process
- Database connections: 0

## Security Tests

### ST-01: A short buffer returns no value

**Summary**: Unpack of a short field does not return a partial value.

**Traces to**: AC-8

**Attack vector**: a truncated packet presented as a complete value

**Test procedure**:
1. Unpack a buffer that ends inside a field
2. Read the returned value

**Expected behavior**: the call returns the error and 0 values

**Pass criteria**: value count is 0, and the error names the field, needed, and left

**Fail criteria**: any field value is returned

### ST-02: The published archive has no registry token

**Summary**: The files published for this package contain 0 registry tokens.

**Traces to**: AC-12

**Attack vector**: a CI secret copied into the archive

**Test procedure**:
1. Build the archive the tag job would upload to NuGet `Packbin`
2. Search the archive for a registry token

**Expected behavior**: the archive is the library only

**Pass criteria**: token count is 0

**Fail criteria**: token count is greater than 0

## Acceptance Tests

### AT-01: Caller pack and unpack

**Summary**: A caller packs the position fixture and unpacks it back.

**Traces to**: AC-1, AC-2

**Preconditions**:
- This package is built
- The golden fixture is on disk

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | `pack` the position value | `4001000065cd1d00a3e1110100`, mismatched bytes 0 |
| 2 | `unpack` that hex | the five fields, motion field count 0 |

### AT-02: Tests run on push and pull request

**Summary**: CI runs this package's tests on every push and pull request.

**Traces to**: AC-11

**Preconditions**:
- The repository is https://github.com/zxsanny/packbin

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a commit that fails one test in this package | the check fails |
| 2 | push a commit whose tests pass | the check passes |

### AT-03: A matching tag publishes this package

**Summary**: A version tag whose golden mismatch count is 0 publishes this package with the other five, and the upload is not manual.

**Traces to**: AC-12, AC-13

**Preconditions**:
- All six languages are in the tagged tree
- Golden mismatch count is 0

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a version tag | this package is on NuGet `Packbin` |
| 2 | install with `dotnet add package Packbin` | the package imports |
| 3 | count manual uploads | 0 |

### AT-04: A golden mismatch publishes nothing

**Summary**: If this package's bytes disagree with the fixture, the tag publishes 0 packages.

**Traces to**: AC-14

**Preconditions**:
- This package's position bytes differ from the fixture

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a version tag | packages published: 0 |

### AT-05: Absent from the tree publishes nothing

**Summary**: A tag whose tree lacks this package publishes 0 packages to its registry.

**Traces to**: AC-15

**Preconditions**:
- This package's project is not in the tagged tree

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | push a version tag | this registry receives 0 packages |

### AT-06: The published package declares MIT

**Summary**: The archive on NuGet `Packbin` declares the MIT license.

**Traces to**: AC-16

**Preconditions**:
- AT-03 has published this package

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | read the license identifier | MIT |
| 2 | count identifiers other than MIT | 0 |

Rollback if this version must not be used: unlist that NuGet version.

## Round Limits (AZ-2216, AZ-2220, loop 15)

No AC number; they hold the F10 limit on the rounds of one unpack call. All run in the `csharp` service of `docker-compose.test.yml`.

| Test | What it proves | Where |
|------|----------------|-------|
| `Ac1_*` | the defaults and constants (65,535 and 1,048,576; 4,194,304 before loop 22); `WithLimits` takes the default, not the receiver's value, for an omitted argument | `csharp/tests/RoundLimitTests.cs` |
| `Ac2_*` to `Ac5_*` | a `Repeat` of `MaxRounds` one-byte rounds is accepted and one more is refused; a `Times` is refused when the next round would start, also for a `u32` count | same file |
| `Ac6_*`, `Ac7_*` | the slot limit counts every name a round can hold; the slot total is shared by the fields of one call, not by two calls | same file |
| `Ac8_*` | a refused 1 MiB packet allocates a bounded amount | same file |
| `Ac9_*` to `Ac11_*` | limits belong to the scheme; a limit below 1 is refused at construction; the largest limits are valid; the existing call shapes compile and behave as before | same file |

The hostile `limit` stage of `fixtures/hostile/cases.txt` (`repeat_rounds_over_limit`, `times_rounds_over_limit`, AZ-2220) is replayed with a scheme whose `maxRounds` is 3: the refusal is the interim bad-value error with `needed` 0 and the one byte of the round that would start left, and the handler is not called.


## Loop 17 (typed rows, split bits, counts, rounds, strict numbers)

Source: `_docs/03_implementation/batch_01_loop17_report.md`, `batch_02_loop17_report.md`, `test_run_loop17_report.md`. The suite went from 424 tests at the start of the loop to 649 on net10.0 and the same 649 on the `netstandard2.0` build. Each file below was written failing first against the previous commit where a "fail before" count is given. All files are in `csharp/tests/`.

| Test class | Task | What it proves | Fail before |
|------------|------|----------------|-------------|
| `TypedParityTests` (10) | AZ-2092 | typed `Pack` and `Unpack` give the same bytes and values as the dictionary form for every kind; pins bytes before the rewrite | 0 of 10 (pins old bytes) |
| `TypedBindingTests` (11) | AZ-2092 | the README C# example packs and unpacks the printed hex; a nested row has its own names (`Name` 1 and 2 pack `01 01 02`); `list` and `dict` members of rows | 9 of 11 |
| `NestedRowFlagByteTests` (3) | AZ-2092 | a flag byte read in a nested row stays in it; `[m, Group(g, m.Bit(x))]` and `[Group(g, m, ...), m.Bit(x)]` are refused | new refusals |
| `Ac10TimingTests.Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` | AZ-2093 | 100 000 public typed round trips (`Pack(Target, row)` and `Unpack(bytes, Target.On(...))`) within 1 s (project AC-10); it moved from `PackbinTests` into its own non-parallel xunit collection with one warm-up call and one strict timed pass in `f0f67ce`, after the first CI run failed it at 1 618 ms inside the parallel suite | the timing in `perf_run_loop17_report.md` |
| `SplitBitOrderTests` (8) | AZ-2135 | split bits numbered by place per read of the flag byte; one handle in two schemes; the ninth bit fails at construction | 8 of 8 |
| `FlagGroupCopyTests` (7) | AZ-2180 | a built scheme does not change when a handle gains a bit | 3 of 7 (fixed by AZ-2135) |
| `FlagGroupPresenceTests` (9), `U2PresenceTests` (8) | AZ-2128 | a nested `Flags`, a split flag bit and a `U2` with any slot present set the group's bit; a set group with a missing value fails naming it | 4 of 9, 2 of 8 |
| `CountKindTests` (44), `CountOverflowTests` (21) | AZ-2181 | a count names an integer field or a `U2` slot or the scheme does not build; a count that does not fit an `int` is an `ArgumentException` | 35 of 44, 20 of 21 |
| `LoneRoundValueTests` (26) | AZ-2182 | a lone value goes to every round; a lone byte run or list for a `Bytes`, `Sized`, `Bits` or `Packed` name is refused | 20 of 26 |
| `GroupElementTests` (10) | AZ-2119 | a `List` or `Dict` of groups unpacks, typed and dictionary | 7 of 10 |
| `StrictNumberTests` (50) | AZ-2191 | dictionary rows pack numbers strictly | 25 of 50 |
| `HostileSessionTests` (6; retired in loop 74, ADR 009), `SplitFormReferenceTests` (3), `FlagScopeContainerTests` (9), `SessionPrivates` (helper; retired in loop 74) | AZ-2114, AZ-2115, AZ-2121 | tests only: hostile session inputs, the split-form reference scheme (`010901045a00`, `010100`), flag-byte scopes of containers | 0 (pins) |

Changed by owner decision (2026-10-06, AZ-2181 reverses C# AZ-2088 AC-6): six `HostileUnpackTests.Counts.cs` float-count tests now assert the construction error, and three `WrittenCountTests` sites expect `ArgumentException`.

## Loop 18 (construction checks, collection members, flags members, strict slots)

Source: `_docs/03_implementation/batch_01_loop18_report.md` to `batch_03_loop18_report.md`, `_docs/loops/loop18/review18.md`, `_docs/03_implementation/test_run_loop18_report.md`. The suite went from 649 to 749 (wave 1), 756 (wave 2), 810 (wave 3) and 844 after the review fixes, on net10.0 and the same 844 on the `netstandard2.0` build. Reference bytes for the flags-member tests: `_docs/03_implementation/flags_member_reference_cases_loop18.md`.

| Test class | Task | What it proves |
|------------|------|----------------|
| `EqBoolTrueOnlyTests` | AZ-2126 | `Eq(bool, v)` with `v` other than `true` is refused at construction (`when 1 tests bool field 0 ('On') against false; a bool is compared only with true`); `Eq(bool, true)` packs `010105`; a `When` on a float, utf8, bytes, sized, bits or packed field is refused (`when 1 tests 'F' (field id 0), a f32 field`) |
| `FloatConditionValueTests` | AZ-2126 | what stays of the deleted `FloatWhenTests`: an integer source against a float condition value (`NaN`, the infinities, `1e30`) compares as the same number and never throws |
| `CollectionMemberTests`, `CollectionElementKindTests` | AZ-2305 | every integer pair of member and field type is accepted only when the member holds the field's range; `Stack`, `HashSet`, `IEnumerable`, a `List<E>` subclass and a `Dictionary` with non-string keys are refused naming the member; `Single` for `F64` refused and `Double` for `F32` accepted; the F25 packet `01 01 00 FF FF FF FF` reads 4294967295 into a `List<long>`; element kinds for `Group`, `Flags`, `List`, `Dict` and `U2` elements (review C2, 28 tests) |
| `EmptyNestedRowTests` | AZ-2306 | an all-null typed nested row under `Flags` fails pack naming the first missing member, at depth 1 and 2; a null row packs `0100`; the filled depth-2 row packs `01010406` |
| `FlagsElementTests`, `DictionaryElementTypedRowTests` | AZ-2307 | a `Flags` list element packs and unpacks (`010300010100020200`) and a dict element (`0102000100780101010079020200`), dictionary and typed; a typed row whose `List<object?>` or `Dictionary<string, object?>` member holds unpacked `Flags` elements repacks to the same bytes (review C1, 4 failing-first tests), and the same repack of anchored or nested-row group elements throws instead of writing wrong bytes |
| `LoneDictRoundTests` | AZ-2308 | a lone dictionary for a `Dict` name in `Repeat` and `Times` is refused naming the member; a list of one dictionary per round packs as before |
| `StrictSlotTests` | AZ-2309 | `U2` slots, `Bits` and `Packed` items refuse fractions, out-of-range values, bool, string, `char`, enum, object and `null`; range edges and whole `double` or `long` values keep their bytes |
| `DictRepackTests` | AZ-2310 | the rows `Read` returns for list and dict group elements repack to the original bytes; an `int` for `Bytes` or `Sized` is an `ArgumentException` naming the member |
| `FlagsWhenMemberTests`, `FlagsRoundMemberTests` | AZ-2120, AZ-2128 | the reference table: `010103075a00`, `0100025a00`, `0101025a00`, the `Times` cases `0100025a00` / `010103055a00` / `01020305065a00` and the `Repeat` cases `0101015a00` / `0101035a0005` / `0101035a000506`; the split and group forms give the same bytes; old packets (bit clear) unpack; the error rows fail naming the value |
| `HostilePackVectorTests` | AZ-2194 | the five `pack` cases of `fixtures/hostile/cases.txt` (C# runs `pack_out_of_range_integer` through the dictionary form) |

Existing tests changed or deleted (the decided concerns reverse them; none weakened): `FloatWhenTests` deleted; `WrittenWhenKindsTests` lost its bytes, sized, bits, packed and utf8 cases; `WrittenWhenTests.Ac7` uses `Eq(0, true)`; five tests deleted because their scheme cannot be built any more (a `When` source that never matches): `HostileUnpackTests.Ac1_RepeatBodyWithANeverMatchingWhen_ReturnsTrailingBytes`, `Reliability_ConditionOnNaNFloat_DoesNotThrow`, `Counts.Times_NeverTrueWhenBodyWithU32MaxCount_ReturnsShortPacketQuickly`, `ZeroWidthElementTests.NeverMatchingWhenListElement_IsError` and `NeverMatchingWhenDictValue_IsError` (the plain zero-width tests stay); `NestedRoundTests.ATimesInADictElementInARound_Builds` binds a `Dictionary` member (it bound a `List<object?>` to a `Dict` field, a test mistake). Running the suite needs `MSBUILDDISABLENODEREUSE=1` (a test starts a child `dotnet build`; without it the run hangs at 646 of 649, `_docs/AGENT_GOTCHAS.md`).

## Loops 19 and later

See [tests-by-loop.md](tests-by-loop.md) (loop 19 to loop 23 sections, moved in loop 23; loop 24 adds Go to the ring, no test change here; loop 71 frame mode; loop 74 retires the stream session tests, ADR 009).

## Test Data Management

**Required test data**:

| Data Set | Description | Source | Size |
|----------|-------------|--------|------|
| position | the 13-byte hex and the five fields | golden fixture file | 13 bytes |
| flags | flags 0x00 and flags 0x20 with a uint16 at bit 5 | the same fixture rows | under 1 KB |
| short | a buffer that ends inside a field | the same fixture rows | under 1 KB |

**Setup procedure**:
1. Build this package
2. Read the golden fixture file. Do not copy the hex into a second list

**Teardown procedure**:
1. Discard the test process
2. Do not leave a registry token on disk

**Data isolation strategy**: each test builds its own value in memory. There is no database and no shared mutable fixture.
