# Test Specification — Rust package

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
1. Build the archive the tag job would upload to crates.io `packbin`
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
| 1 | push a version tag | this package is on crates.io `packbin` |
| 2 | install with `cargo add packbin` | the package imports |
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

**Summary**: The archive on crates.io `packbin` declares the MIT license.

**Traces to**: AC-16

**Preconditions**:
- AT-03 has published this package

**Steps**:

| Step | Action | Expected Result |
|------|--------|-----------------|
| 1 | read the license identifier | MIT |
| 2 | count identifiers other than MIT | 0 |

Rollback if this version must not be used: yank that crates.io version.

## Round Limits (AZ-2219, AZ-2220, loop 15)

No AC number; they hold the F10 limit on the rounds of one unpack call. All run in the `rust` service of `docker-compose.test.yml`.

| Test | What it proves | Where |
|------|----------------|-------|
| `ac1_*` | the defaults and constants; `with_limits` on a `MapScheme`; existing call sites unchanged | `rust/tests/round_limits_tests.rs` |
| `ac2_*` to `ac5_*` | `repeat` and `times` accept 65,535 rounds and refuse the next one as `Short { field: "repeat" \| "times", needed: 0 }` | same file |
| `ac6_*` to `ac8_*` | the slot limit refuses the round that would pass it; the slot total is shared by the fields of one call; a `times` inside a `repeat` counts its rounds afresh and its slots together | same file |
| `ac9_*`, `ac10_*` | a typed `times` row is limited and its handler is not called; refused 1 MiB packets stop at round 65,536 | same file |
| `ac11_*`, `ac12_*` | limits belong to the scheme; a zero limit panics on a map and a typed scheme; `usize::MAX` is valid | same file |

The hostile `limit` stage of `fixtures/hostile/cases.txt` (`repeat_rounds_over_limit`, `times_rounds_over_limit`, AZ-2220) is replayed with a scheme whose `max_rounds` is 3: the refusal is the interim bad-value error with `needed` 0 and the one byte of the round that would start left, and the handler is not called.


## Loop 16 Tests (AZ-2105, AZ-2114, AZ-2117, AZ-2118, AZ-2121, AZ-2128, AZ-2189, AZ-2237, AZ-2247)

All run in the `rust` service of `docker-compose.test.yml` with `cargo test`.

| Test | What it proves | Where |
|------|----------------|-------|
| `ac1_*` to `ac4_*` name-scope tests | a `when` or count naming an outer field, an earlier body's field, a later field or an undeclared name, by name or by id, panics at construction naming the owner; same-scope references still build and round-trip (AZ-2117) | `rust/src/name_scope_tests.rs` |
| session pack tests | `PackSession::pack` returns `Err(NotOpen)` before open and leaves the counter at zero, returns the `PackError` of clear pack, and a failed pack uses no pad position (AZ-2105) | `rust/tests/session_tests.rs`, `rust/tests/times_shapes_tests.rs` |
| `ac1_count_2_pow_63_with_bias_minus_one_is_a_pack_error` | a `packed` count of 2^63 with bias -1 is a `PackError::Type` (AZ-2118) | `rust/src/borrowed_count_tests.rs` |
| map `times` under `flags` and `when` | a non-empty list or a single value under such a member is refused naming it; an empty list, an absent member, rounds and direct members still pack (AZ-2189) | `rust/src/times_tests.rs` |
| `ac1_*` and `ac2_*` flag group tests | a group of `u2`, `sized`, `bits`, `packed`, a nested group or nested `flags` sets its bit, at any depth; a missing sibling fails with `PackError::Missing` naming it (AZ-2128) | `rust/src/flag_group_tests.rs` |
| `ac1_*`, `ac2_*`, `r2_g1_*` hostile session tests | a waiter unpacking a zero-progress packet, a list of zero-width lists or a dict with a zero-width value returns the clear-unpack error, and the next valid message unpacks (AZ-2114; the zero-progress scheme uses a zero-width `bytes` repeat, because the README `when` scheme is refused at construction) | `rust/src/session_hostile_tests.rs` |
| `ac1_*` to `ac5_*` written-value tests | a `when` on a field that an earlier `when` or a clear bit skipped does not match; the typed scheme agrees; `eq(bool, false)` on a clear bit writes no body; a `sized`, `bits`, `packed` or `times` count that names a skipped field is `PackError::Missing`; a `repeat` or `times` round decides from what the round wrote (AZ-2237; 11 tests) | `rust/src/when_written_tests.rs` |
| `ac8_*` kept-bytes tests | the chains, rounds, split flag byte, `u2` slot and flags byte that already packed correctly keep their bytes (AZ-2237; 7 tests) | `rust/src/when_kept_tests.rs` |
| `a_when_on_a_flags_byte_*`, `a_count_that_names_*`, `a_name_a_times_round_wrote_*` | a `when` or count that names a `flags` byte or a split flag byte reads the byte pack wrote, not a value kept in the row (`0105010709`, `0101010508`, `010105aa`); after a `times` the names its rounds wrote are lists, so a `when` on one does not match and its body is not written (`0101000007`), with rounds or per-name lists; a count of such a name is not an integer (AZ-2237 review fixes; 11 tests) | `rust/src/when_names_tests.rs` |
| `ac6_*`, `ac7_*` and three later tests | a map `times` without rounds refuses a list longer than the count by name (`times at id 1: '1' has 3 items, count is 2`), also for count 0, and names the first member in field order; a list as long as the count, a shorter list, an empty or absent list and a lone value keep their results; a list under the name of a `flags` member is not refused, a flag-bit inner longer than the count is (AZ-2237; 14 tests) | `rust/src/times_longer_tests.rs` |
| `AZ-2247 a data member name declared twice is refused` (29 tests) | `MapScheme::new` and `Scheme::new` panic with the whole message for the same name twice at one level, once outside and once inside a `times` round (both orders), two `times` bodies that share a name, a `times` body that names a member twice, a name inside and outside a `repeat` round, and 14 shapes (every data kind and every container that shares the scope), and for a raw `SchemeItem::Field` twice in a typed scheme; alternate `when` branches, a name outside then under a `when` and two in one `when` body, a flag byte read twice, two `flags` bytes named alike, and a list element named like a row member build; typed bound fields with one id keep the id message; five schemes keep their existing message after a duplicate (10 tests refuse, 19 pin; two files, `duplicate_names_tests.rs` 320 lines and `duplicate_names_kept_tests.rs` 210 lines) | `rust/src/duplicate_names_tests.rs`, `rust/src/duplicate_names_kept_tests.rs` |
| orphan split-bit tests | a typed list whose element is a bare flag bit, and a `flags` member split bit without or before its flag byte, are refused at construction (AZ-2121) | `rust/src/element_tests.rs` |

## Loop 19 Tests (AZ-2329 to AZ-2338, AZ-2342)

Source: `_docs/03_implementation/batch_01_loop19_report.md`, `_docs/loops/loop19/review19.md`, `_docs/03_implementation/test_run_loop19_report.md`. The suite went from 479 to 526 (wave 1), 528 and 533 after the review fixes (436 lib tests and 97 in the other targets); clippy is clean in the touched files.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `pack_round_cap_tests.rs` | AZ-2329 | `PackError::Type` for a count of 65 536, 70 000 and 4 000 000 000 in `times`, `__times_N`, a round, `flags` and a group; 65 535 packs; `with_limits(2, ..)` refuses 3 |
| `split_form_loud_tests.rs` | AZ-2331 | a clear split bit errors when a `when` source or `times` count is written after the byte and the body would be written, or the count is not written; the false condition, the combined form and a never-written source (review A2) are silent; `ac3_split_form_when_false_...` rewritten |
| `flags_member_scope_tests.rs` | AZ-2333 | each `flags` member has its own flag-byte scope; scheme S1 packs `0103030301050607` (TypeScript's bytes) and the other four rows match; S2 with no outer byte panics at construction |
| `lone_bytes_in_round_tests.rs` | AZ-2332 | a lone `Value::Bytes` in a `times` round is refused (count 1 too); `utf8` still broadcasts |
| `times_count_zero_tests.rs` | AZ-2335 | count 0 with a list or rounds errors; a lone scalar packs `0100` |
| `eq_range_tests.rs` | AZ-2338 | `U16(300)` on `u8`, `U32(70000)` on `u16`, `I16(200)` on `i8`, `I8(-1)` on `u64`, `U64::MAX` on `i64`, a `u2` slot 4 and a flag byte 256 panic at construction |
| `hostile_tests.rs` (438 lines) | AZ-2329 to AZ-2338 | the eight new hostile cases |

Existing tests changed: `az2311_ac2_...` (lone buffer), `eq(i8, U8(255))` and `eq(u64, I64(-1))`, `flags_when_member_tests.rs`, `integrity_tests.rs`, `times_lone_value_tests.rs`. File split (AZ-2342): `walk/cursor.rs` and `field/leaf.rs` moved out of `walk/unpack.rs` and `field/mod.rs`; 479 tests before and after.

## Loop 20 Tests (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2365, AZ-2367)

Source: `_docs/03_implementation/batch_01_loop20_report.md` to `batch_04_loop20_report.md`, `_docs/loops/loop20/review20.md`, `_docs/03_implementation/reference_loop20_budget.md`, and the scenario mapping in `_docs/02_document/tests/blackbox-tests-13-loop20-pack-budget-and-parity.md` (FT-X-38 to FT-X-52). The library tests went from 436 to 469 (wave 1b), and the whole suite from 533 to 566 and 569 after the review fix pass: 472 lib tests plus 97 in the integration binaries. The AZ-2354 rows that need a `times` or `repeat` in a list element have no Rust equivalent (construction refuses it).

| Test file | Task | What it proves |
|-----------|------|----------------|
| `pack_output_budget_tests.rs` | AZ-2354 | `ac1_row1_a_lone_utf8_under_a_capped_times_is_refused_at_once_naming_the_member`; the boundary rows 4 to 13; `ac4_row14_*` and the slot rows; `ac5_rows26_28_limits_api`, `ac5_row27_a_zero_max_bytes_is_refused` (and for the typed scheme) |
| `pack_repeat_cap_tests.rs` | AZ-2355 | `ac1_row1_*`, `ac2_row2_*`, `ac3_row3_*`, rows 4 to 9 (the list-element row 10 does not apply) |
| `loop20_parity_pins_tests.rs` | AZ-2356, AZ-2359, AZ-2360, review A4 | `az2356_ac1_*`, `az2356_ac2_*` (a lone scalar now packs `010000`, was refused), `review20_a4_the_split_form_keeps_count_zero_after_the_byte`; `az2360_ac1_*`, `review20_a4_a_skipped_count_with_a_stale_zero_is_refused_under_flags_naming_the_member` (failed on HEAD with `expected a type error, got Ok([1, 0, 0])`); `az2359_ac1_a_u8_slot_takes_only_an_integer_value` |
| `hostile_tests.rs` | AZ-2367 | a `PACK_NOT_RUN` table (the list-element case is skipped with its reason); 491 lines |
| `scheme/bound_collections.rs` | AZ-2365 | not a test file: split out of `scheme/bound.rs` (514 to 357 lines); the suite is unchanged by the move |

Slow tests: the AC-4 slot rows take about 20 s in a debug build (rows 14 and 15 measured 8.5 s and 17.7 s; 0.8 s in release) and the hostile slots case 8.1 s in debug; kept at spec size (review A9). Decide with the total run whether CI should use a release build or smaller limits.

## Loop 21 Tests (AZ-2382, AZ-2384, AZ-2385, AZ-2386, AZ-2387, AZ-2390, AZ-2392, AZ-2394)

Source: `_docs/03_implementation/batch_01_loop21_report.md`, `test_run_loop21_report.md`, `reference_loop21_slots.md`. The suite went from 569 to 625 tests (step 11 container run); 22 of the 49 new tests failed on a `git archive HEAD` copy of the sources before the change.

Test files: `rust/tests/round_slot_width_tests.rs` (AZ-2382: rows 1 to 14), `empty_round_body_tests.rs` (AZ-2390: rows 15 to 26 that a map scheme can express), `late_when_in_bit_body_tests.rs` (AZ-2385), `loop21_parity_probes_tests.rs` (AZ-2384, AZ-2386, AZ-2387 pins) and `count_behind_clear_when_tests.rs` (AZ-2386, AZ-2387: rows 44 to 56), `src/hostile_tests/refusals.rs` and `src/hostile_tests/pack_cases.rs` (AZ-2392, AZ-2394; `hostile_tests.rs` shrank by the split). Changed: `pack_output_budget_tests.rs` and `scope_tests.rs` (the narrower width).

## Loop 22 Tests (AZ-2410, AZ-2412, AZ-2414, AZ-2415, AZ-2417, AZ-2418)

Source: `_docs/03_implementation/batch_01_loop22_report.md`. The suite is 489 lib and integration tests.

Test files: `tests/loop22_parity_tests.rs` (AZ-2410 rows 56 to 56d, AZ-2414 rows A1 to A11 and shape B, AZ-2415 default and the 64-slot-round packet), `repeat_lists_without_groups_tests.rs` (AZ-2412: refusals and unchanged rows), `times_tests.rs` and `times_longer_tests.rs` (three "under a flags member is refused" pins replaced by decision; a longer list still refused), `tests/count_behind_clear_when_tests.rs`, `tests/loop21_parity_probes_tests.rs`, `tests/round_limits_tests.rs` and `pack_output_budget_tests.rs` (numbers), `hostile_tests.rs` with `hostile_tests/pack_cases.rs` and `hostile_tests/refusals.rs` (AZ-2417; AZ-2418 four tests: wrong pack entry, wrong construct entry, entry for a case that is not refused, refused case without entry). Scenarios FT-X-66, FT-X-68, FT-X-70, FT-X-71, FT-X-73, FT-X-74.

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
