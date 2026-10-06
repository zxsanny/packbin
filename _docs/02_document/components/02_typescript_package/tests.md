# Test Specification — TypeScript package

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
1. Build the archive the tag job would upload to npm `packbin`
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
| 1 | push a version tag | this package is on npm `packbin` |
| 2 | install with `npm install packbin` | the package imports |
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

**Summary**: The archive on npm `packbin` declares the MIT license.

**Traces to**: AC-16

**Preconditions**:
- AT-03 has published this package

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | read the license identifier | MIT |
| 2 | count identifiers other than MIT | 0 |

Rollback if this version must not be used: deprecate that npm version.

## Round Limits (AZ-2217, AZ-2220, loop 15)

No AC number; they hold the F10 limit on the rounds of one unpack call. All run in the `typescript` service of `docker-compose.test.yml`.

| Test | What it proves | Where |
|------|----------------|-------|
| `scheme limits surface` | the defaults and constants; `withLimits` takes the default for a member left out and keeps the type number; existing call sites unchanged; a derived scheme with a bound reference packs and unpacks like its source | `typescript/tests/round-limits.test.ts` |
| `repeat limits`, `times limits`, `times at the default limit` | `maxRounds` rounds are accepted and round `maxRounds` + 1 is refused with its byte unread; a huge `times` count that never reaches the limit keeps its short read | same file |
| `slot limit`, `limits of a large packet` | the slot total is shared by every field of one call; a 1 MiB packet of one-byte rounds with 36 names is refused after 65,535 rounds | same file |
| `limits belong to the scheme`, `invalid limits` | each scheme and each dispatch handler uses its own limits; a limit that is not a positive safe integer is a `RangeError`, in `withLimits` and in the constructor | same file |

The hostile `limit` stage of `fixtures/hostile/cases.txt` (`repeat_rounds_over_limit`, `times_rounds_over_limit`, AZ-2220) is replayed with a scheme whose `maxRounds` is 3: the refusal is the interim bad-value error with `needed` 0 and the one byte of the round that would start left, and the handler is not called.


## Loop 16 Tests (AZ-2112 to AZ-2197, AZ-2128, AZ-2135, AZ-2115, AZ-2103, AZ-2236, AZ-2238, AZ-2240)

No AC number from the first acceptance set; each file names the task and its ACs in its test titles. All but the package check run in the `typescript` service of `docker-compose.test.yml` with `node --test tests/*.ts`.

| Test | What it proves | Where |
|------|----------------|-------|
| `u64 counts` | `sized`, `packed`, `times` and `bits` take a count from a `u64` or `i64` field; a count above 2^53, a negative one and the `i64` minimum are refused (error value on unpack, `RangeError` on pack); a row that unpack returned packs again | `typescript/tests/u64-count.test.ts` |
| `list and dict elements of kind group and flags` | each item packs from its own members and unpacks to one object, with the bytes of Python; a short element is an error; an element is a scope of its own | `typescript/tests/list-group-elements.test.ts` |
| `times with a list longer than its count` | pack throws `x: 3 items, times count 2`; count 0 refuses a non-empty list; valid rows keep their bytes | `typescript/tests/times-longer-list.test.ts` |
| `flags under a split flag bit and flags directly inside flags` | their values pack (`01 01 07 01 02`); a repack identity fuzz with the seeded generator | `typescript/tests/flags-under-split-bit.test.ts`, `typescript/tests/support/random.ts` |
| `dict entries are not members of the row` and the three groups after it | a dict key cannot overwrite or supply a row member in either key order; declared groups still merge; a decoded `__proto__` key stays an entry; the fixtures that use dictionaries are unchanged | `typescript/tests/dict-keys-not-flattened.test.ts` |
| `a member name declared twice in one scope` | the schemes of AZ-2188 fail at construction; two `when` branches may share a name; a list or dict element has its own names | `typescript/tests/duplicate-names.test.ts` |
| `when and counts read what pack wrote`, `pack never writes what its own unpack cannot read` | a `when` on a skipped field does not match, `eq(id, undefined)` follows unpack, `eq(bool, false)` on a clear bit writes no body, a count that was not written throws | `typescript/tests/when-on-written-values.test.ts` |
| `a flags group is on when any value inside it is present` | `u2`, `bits`, `sized`, `packed`, nested `flags` and groups set the bit; a set group lacking a member throws naming it | `typescript/tests/flag-group-presence.test.ts` |
| `AZ-2135 split bits are numbered by field order` | a handle shared by two schemes packs `010105` twice; `[m, early, late]` packs `010209`; a second read starts its own bits (`01000109`); nested bits number the outer one first; the ninth bit of one read is refused when the scheme is built; the position golden bytes in split form | `typescript/tests/split-bits-field-order.test.ts` (the ninth-bit case of `bool-flag.test.ts` now builds a scheme) |
| `AZ-2115 split-form reference bytes` | `{sid: 9, shape: 4, heading: 90}` packs `01 09 01 04 5a 00` and `{sid: 1}` packs `01 01 00`, and both unpack to the same row | `typescript/tests/split-form-reference.test.ts` |
| `AZ-2236 a list or dict of anchored groups is refused` | `scheme(...)` and `new Scheme(...)` throw `list g: element is an anchored group (p); use a group without an anchor` (`dict g: ...` for a dict) for the element in a `when`, `repeat` or `times` body, an unanchored group element, a `flags` member, a flag bit, `flags` directly in `flags` and an inner dict; `when` and `times` elements keep their own refusals; ten schemes that build keep their packed bytes and round-trip; an earlier refusal elsewhere in the scheme comes first (26 tests; the TypeScript suite is 463) | `typescript/tests/list-element-kinds.test.ts` |
| npm package layout (AZ-2103) | `publish-check.py` accepts the compiled layout and refuses sources-only and dist-plus-sources tarballs; `package.json` points at `dist`; `publish-inside.sh` builds before it packs from a copy that holds a stale `dist`; the tarball holds `dist/index.js`, `dist/index.d.ts`, `README.md` and `package.json` and no `src/` or `tests/`; the built JavaScript has no Node-only name and imports only `@noble/hashes`; an empty project with no TypeScript installs the tarball and packs the golden row under plain Node; a strict `tsc` consumer with no `allowImportingTsExtensions` type-checks and cannot pack without a scheme | `.github/workflows/publish-npm.test.sh` (run by `publish-gate.test.sh`, or alone with `--npm`; the `scaffold` job) |
| `npm_guard_checks` (AZ-2240) | the tag-time guard (`publish-check.py typescript`) passes on the real tarball and fails, with the message that names the part, for `exports` removed, pointed at `src` or without `types`, `types` removed or pointed at `src`, a `dist/*.js` or `dist/*.d.ts` that another file imports but the tarball lacks (`walker.js`, `walker.d.ts`), and a `./nope.js` or `./nope.ts` import | `.github/workflows/publish-npm.test.sh` |
| `publish-position.test.sh` (AZ-2238) | `publish-position.sh typescript` on a tree without `typescript/node_modules` prints the golden hex, installs only into its own work copy, and leaves no temp directory; the temp directory is reached through a symlink, as on macOS (it failed with `Missing: typescript@... from lock file` when the script ran `npm ci --prefix`); the gate runs it as a child process | `.github/workflows/publish-position.test.sh` |

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
