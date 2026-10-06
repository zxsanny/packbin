# Test Specification — Java package

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
1. Build the archive the tag job would upload to Maven Central `packbin`
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
| 1 | push a version tag | this package is on Maven Central `packbin` |
| 2 | install with the Maven or Gradle coordinate for `packbin` | the package imports |
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

**Summary**: The archive on Maven Central `packbin` declares the MIT license.

**Traces to**: AC-16

**Preconditions**:
- AT-03 has published this package

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | read the license identifier | MIT |
| 2 | count identifiers other than MIT | 0 |

Rollback if this version must not be used: publish a later Maven Central version. A published version stays.

## Platform Checks (AZ-2094, loop 14)

No AC number; they hold the Java 17 and Android API 26 target. All run in `java/test.sh` (the `java` service of `docker-compose.test.yml`) except the last.

| Check | What it proves | Where |
|-------|----------------|-------|
| `javac --release 17` on main and test sources | no Java 18+ language feature or API in main or tests | `java/test.sh` |
| `api-check` | the compiled main classes call no API above Android API 26 (Animal Sniffer, `android-api-level-26` signature) | `java/api-check.sh` |
| `ApiSafeReplacementsTest.dictKeysSortAsUnsignedBytes` | dict keys with `""`, ASCII and non-ASCII sort as unsigned UTF-8 bytes; the packed hex is the one recorded before the change | `java/src/test/java/packbin/ApiSafeReplacementsTest.java`, run from `PackbinTest` |
| `ApiSafeReplacementsTest.fieldChildrenAreAnImmutableCopy`, `schemeFieldsAreAnImmutableCopy` | `Field.children` and `Scheme.fields` are copies of their source and refuse modification with `UnsupportedOperationException` | same file |
| class major version 61 on every jar class | the published jar targets Java 17 | `publish-check.py` in the publish build phase |

## Round Limits (AZ-2218, AZ-2220, loop 15)

No AC number; they hold the F10 limit on the rounds of one unpack call. All run in `java/test.sh` (`RoundLimitsTest.run()` is called from `PackbinTest`).

| Test | What it proves | Where |
|------|----------------|-------|
| `defaultsAndSurface`, `existingCallSitesAreUnchanged` | the defaults and accessors; `withLimits(int, long)` returns a new scheme; existing call shapes unchanged | `java/src/test/java/packbin/RoundLimitsTest.java` |
| `repeat*`, `times*` | `maxRounds` rounds are accepted at the default limit and the next round is refused with `ShortPacket(label, 0, left)` for `repeat`, `times` and a `u32` count | same file |
| `slotLimit`, `slotTotalSpansFieldsAndElements` | the slot limit counts the value fields of the body; the total spans fields and elements of one call | same file |
| `refusedMegabyteIsBoundedByTheLimits`, `limitsBelongToTheScheme`, `invalidLimitsAreRefused` | a refused 1 MiB packet is bounded; each scheme has its own limits; a limit below 1 is an `IllegalArgumentException` | same file |

The hostile `limit` stage of `fixtures/hostile/cases.txt` (`repeat_rounds_over_limit`, `times_rounds_over_limit`, AZ-2220) is replayed with a scheme whose `maxRounds` is 3: the refusal is the interim bad-value error with `needed` 0 and the one byte of the round that would start left, and the handler is not called.


## Loop 16 Tests (AZ-2101, AZ-2114, AZ-2121, AZ-2127, AZ-2128, AZ-2135, AZ-2187, AZ-2190, AZ-2233 to AZ-2235)

All run in `java/test.sh` (the `java` service of `docker-compose.test.yml`); each class is called from `PackbinTest`.

| Test | What it proves | Where |
|------|----------------|-------|
| `NestedRoundTest` | a `repeat` or `times` inside a round packs and unpacks one inner list per outer round (`null` for a skipped round, `[]` for a group that read no round); a repeat written a second time in one call is refused; an exhaustive short-packet sweep never throws (AZ-2127) | `java/src/test/java/packbin/NestedRoundTest.java` |
| `TimesLongerTest` | a body list longer than the count is refused (`1: list has 3 entries for a count of 2`); a nested row, list or dict member is named by its kind (AZ-2187) | `java/src/test/java/packbin/TimesLongerTest.java` |
| `PackStrictTest` | out-of-range integers, a wrapping `BigInteger`, fractions, strings, booleans, an oversize float and odd `Number` types are refused with `IllegalArgumentException` naming the field id; valid rows keep their bytes; `PackSession.pack` refuses the same (AZ-2190) | `java/src/test/java/packbin/PackStrictTest.java` |
| `TypedNestedRowTest` | a typed nested row is created by its factory in a round and as a list or dict element; the old overload on a typed row fails at construction; nested ids never shadow the ids of the row around them (`010001`) (AZ-2101); a list or dict element group without a factory is refused (`list element: ...`, `dict element: ...`) wherever the holding scope is typed, a factory builds, and the anchored group, `flags`, `Map` and `HashMap.class` cases stay as they were (S4 to S8, S12; AZ-2235) | `java/src/test/java/packbin/TypedNestedRowTest.java` |
| `FlagPresenceTest` | `u2`, nested `flags` and a split bit in a group set the bit of the group; a missing sibling fails pack naming it (AZ-2128) | `java/src/test/java/packbin/FlagPresenceTest.java` |
| `MissingNestedValueTest` | a `null` or absent nested-row member throws `missing group`, under a `when` only when it holds, in every round below the count; a row read by unpack still packs back; a `null` list or dict element throws `missing list element 1` and `missing dict element "b"`, a typed list element too, other element kinds keep their messages; `PackSession.pack` throws and sends no frame (AZ-2234; new class, registered in `PackbinTest`) | `java/src/test/java/packbin/MissingNestedValueTest.java` |
| `TypedElementScopeTest` | an anchored-group, a `flags` and a dict element on a typed `Holder` stay unrefused (`01 0100 03`, `01 0100 01 03`); it fails if the element scope is checked as typed (AZ-2235 review) | `java/src/test/java/packbin/TypedElementScopeTest.java` |
| `RepeatRoundTest`, `FlagPresenceTest`, `PackStrictTest` (AZ-2234 cases) | `u2` in a round packs the item of each round (`01 0d 02`); a `null` nested row under `flags` clears the bit; presence and `u2` agree in a round; `u2` outside a round is unchanged | `java/src/test/java/packbin/RepeatRoundTest.java`, `FlagPresenceTest.java`, `PackStrictTest.java` |
| `HostileSessionTest` | a session waiter gets the clear-unpack error for the zero-progress packet and the zero-width elements, and the next valid message unpacks (AZ-2114) | `java/src/test/java/packbin/HostileSessionTest.java` |
| `FlagScopeContainerTest` | a split bit in a dict element, or held by a combined `flags` member, with no flag byte earlier in its scope is refused; the same-scope shapes build (AZ-2121) | `java/src/test/java/packbin/FlagScopeContainerTest.java` |
| `SplitBitOrderTest` | a handle shared by two schemes packs `010105` twice; a second read starts its own bits (`01000109`); `[m, early, late]` packs `010209`; the ninth bit of one read is refused at construction; a flag byte read inside a nested row belongs to that row (`010301010203`); a bit after a row whose only byte was read inside it is refused (AZ-2135); a bit inside a nested row whose only byte was read outside it is refused in eight shapes with `flag bit U8 0 has no flagByte before it in the same scope`, and a typed row is refused the same way (`az2233Ac1` to `Ac5`, AZ-2233) | `java/src/test/java/packbin/SplitBitOrderTest.java` |

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
