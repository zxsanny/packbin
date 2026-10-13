# Blackbox Tests 7: The hostile case file and C++ scope rules (FT-X-01 to FT-X-10)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md).

### FT-X-01: The hostile case file is well formed

**Summary**: The hostile case file is well formed (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2070 AC-1, AZ-2070 AC-2, AZ-2070 AC-3, AZ-2070 AC-4, AZ-2194 AC-1, AZ-2194 AC-2, AZ-2194 AC-3, AZ-2194 AC-9
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `fixtures/hostile/cases.txt` (25 cases: 10 `unpack`, 8 `construct`, 2 `limit`, 5 `pack`), 18 corrupted copies of it, 7 corrupted copies of `fixtures/hostile/README.md` and a README copy without one section (26 corruptions in all, loop 18)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `fixtures/hostile/cases.test.sh` (the `scaffold` job runs it) | `hostile cases ok: 25`; each of the 26 corrupted copies exits non-zero and names its line or its id; every id has a README section; a `pack` id also has `Scheme`, `Row`, `Run by` and `Not run by` lines that name each of the six packages exactly once |

**Expected outcome**: 25 ids pass; each of the 26 corrupted copies exits non-zero and names its line or its id; every id has a README section; a `bytes` line carries lowercase even hex starting `01`, a `pack_error` line carries `-`, and only the `pack` stage may use either term. Loop 19 (AZ-2329, AZ-2331, AZ-2332, AZ-2335, AZ-2338): the file has 33 cases (10 `unpack`, 9 `construct`, 2 `limit`, 12 `pack`), `cases.test.sh` and `check-cases.sh` print `hostile cases ok: 33`, the 26 corruptions are unchanged; the eight new ids are `eq_out_of_range`, `pack_times_count_over_limit`, `pack_times_zero_with_values`, `pack_split_when_source_after_byte`, `pack_split_times_count_after_byte`, `pack_split_times_count_skipped`, `pack_lone_bytes_in_round` and `pack_split_false_condition_silent` (FT-X-24, FT-X-26, FT-X-27, FT-X-30, FT-X-33). Loop 20 (AZ-2354, AZ-2355, AZ-2356, AZ-2360, AZ-2367): the file has 40 cases (10 `unpack`, 9 `construct`, 2 `limit`, 19 `pack`), `cases.test.sh` and `check-cases.sh` print `hostile cases ok: 40`, the 26 corruptions are unchanged; the seven new ids are `pack_lone_utf8_under_times_over_budget`, `pack_element_times_over_budget`, `pack_slots_over_limit`, `pack_repeat_over_limit`, `pack_split_count_zero_after_byte_list`, `pack_split_count_zero_after_byte_scalar` and `pack_flags_skipped_count_with_values` (FT-X-38 to FT-X-41, FT-X-43 to FT-X-45).
**Max execution time**: 5s

### FT-X-02: A reused flag-byte number keeps its own scope

**Summary**: A reused flag-byte number keeps its own scope (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2078 AC-1, AZ-2078 AC-2
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a scheme whose `times` items use `flag_byte(0)` like the outer scope

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack the row with the inner bit clear, then set | bytes `010101000203` and `0101000107`; both round-trip |

**Expected outcome**: bytes `010101000203` and `0101000107`; both round-trip.
**Max execution time**: 1s

### FT-X-03: A round that reads nothing ends the container

**Summary**: A round that reads nothing ends the container (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2078 AC-3
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: an empty `repeat`, bound and unbound, and bytes `01 05 09`; an unbound empty `times` with count `0xffffffff`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack | `TrailingBytes` at offset 2 and count 0; the `times` returns Ok at once |

**Expected outcome**: `TrailingBytes` at offset 2 and count 0; the `times` returns Ok at once.
**Max execution time**: 1s

### FT-X-04: The hostile vectors give allowed outcomes in C++

**Summary**: The hostile vectors give allowed outcomes in C++ (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2078 AC-4, AZ-2126 AC-3, AZ-2194 AC-8
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: 22 of the 25 cases in `fixtures/hostile/cases.txt`: the 10 `unpack` cases, the 8 `construct` cases (including `eq_bool_false`, built as `eq(0, 0)` at run time because the literal `eq(0, false)` is a compile error) and 4 of the 5 `pack` cases. Skipped with a printed reason: the 2 `limit` cases (C++ has no round limit, AZ-2220) and `pack_out_of_range_integer` (a typed row binds a `std::uint8_t`, so 300 cannot be written)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | the host runner builds each scheme by hand and unpacks, validates or packs it | each outcome is one the file allows (a `pack` case: the packet hex, or `BadValue` with no bytes); each case within 1 s; bytes written outside the row 0; every skipped case prints its reason |

**Expected outcome**: each outcome is one the file allows; each case within 1 s; bytes written outside the row 0; 22 cases run and 3 are skipped with a reason. Loop 19: 28 of 33 cases run and 5 are skipped with a reason (the two `limit` cases, `pack_out_of_range_integer`, `pack_times_count_over_limit` and `pack_lone_bytes_in_round`); `pack_split_*`, `pack_times_zero_with_values` and `eq_out_of_range` run (the last builds the scheme at run time with the constant 300). Loop 20: 30 of 40 cases run and 10 are skipped with a reason; of the seven new `pack` cases only `pack_split_count_zero_after_byte_list` and `pack_flags_skipped_count_with_values` run, and the other five are skipped (`kPackSkips` in `cpp/tests/core/hostile_pack_cases.hpp`: no output budget, no slot budget, no repeat cap, a typed row holds an `Array` so a lone scalar cannot be written).
**Max execution time**: 22s

### FT-X-05: A bool or empty group outside flags is refused

**Summary**: A bool or empty group outside flags is refused (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2081 AC-1, AZ-2081 AC-2
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: schemes with a top-level `boolean`, an empty `group` at top level, in a `group`, a `when`, a `repeat`, a `times` and a `list`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build, then pack or unpack | compile error naming the id (`constexpr`); `SchemeInvalid` at run time with 0 bytes written |

**Expected outcome**: compile error naming the id (`constexpr`); `SchemeInvalid` at run time with 0 bytes written.
**Max execution time**: 1s

### FT-X-06: A bool inside flags is unchanged

**Summary**: A bool inside flags is unchanged (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2081 AC-3
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: `flags(boolean, u8)` with the bool true and false; `flag_byte` with `flag_bit(boolean)` true, false and absent

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack and unpack | `010307` and `010207`; `0101` and `0100`; unpack sets the bool only for a set bit |

**Expected outcome**: `010307` and `010207`; `0101` and `0100`; unpack sets the bool only for a set bit.
**Max execution time**: 1s

### FT-X-07: A u2 holds at most 64 children

**Summary**: A u2 holds at most 64 children (loop 10, C++ on microcontrollers and the bug-fix epic AZ-2069).
**Traces to**: AZ-2081 AC-4
**Category**: Errors

**Preconditions**:
- The C++ core as built in loop 10

**Input data**: a `u2` with 64 and with 65 `u8` children

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build; for 64 pack and unpack | 65 fails construction; 64 packs to 16 bytes and round-trips |

**Expected outcome**: 65 fails construction; 64 packs to 16 bytes and round-trips.
**Max execution time**: 1s

### FT-X-08: `eq` on a bool accepts only `true`

**Summary**: A `when` whose `eq` names a bool or an empty-group mark fails scheme construction unless the compared value is `true`, in every package (loop 18, AZ-2126).
**Traces to**: AZ-2126 AC-1, AZ-2126 AC-2, AZ-2126 AC-3
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 1 construction check, wave 2 vector)

**Input data**: the scheme `flags(0, bool on)`, `when(1, eq(0, v), u8 v)` with `v` = `false` (and `0`, `2`, `-1`, `"yes"` where the language can write them); the hostile construct vector `eq_bool_false`; the same scheme with `eq(0, true)` and the rows `{on: true, v: 5}` and `{on: false}`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the scheme with `eq(0, false)` | construction fails naming the `when` and field 0 (exception in C#, TypeScript, Python, Java and Rust; `SchemeInvalid` in C++, and the literal `eq(0, false)` is a compile error: `cpp/tests/compile-fail/when_eq_bool_false.cpp`) |
| 2 | build the same scheme with `eq(0, true)`; pack `{on: true, v: 5}`; unpack the bytes | hex `010105`; the row `{on: true, v: 5}` |
| 3 | pack `{on: false}` with the `eq(0, true)` scheme | hex `0100`; the `when` body is left out; unpack gives `{on: false}` |

**Expected outcome**: step 1 is `scheme_error` in all six packages (the vector `eq_bool_false`; C++ builds `eq(0, 0)` at run time); step 2 gives `010105` and the same row in all six; step 3 gives `0100`. Rust has no bool value: its bool is an empty group, `false` is `U8(0)` and `true` is `eq(id, 1)`.
**Max execution time**: 1s

### FT-X-09: A `when` or a count names an integer field only

**Summary**: A `when` may name an integer field or a bool (a bool only with `true`); a count (`sized`, `bits`, `packed`, `times`) may name an integer field only; any other source fails scheme construction in every package (loop 18, AZ-2126, owner decision 2026-10-06).
**Traces to**: AZ-2126 AC-1
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 1)

**Input data**: a `when` whose source is a float, a utf8, a bytes, a sized, a bits or a packed field; a `times`, `sized`, `bits` or `packed` count whose source is a bool, a float or another counted field; controls: a `when` on `u8`, `i64`, a `be()` field and a `u2` slot, a `when` on a bool with `eq(.., true)`, a count on `u8` and on a `u2` slot

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build each refused scheme | construction fails naming the `when` or the count and the source field |
| 2 | build each control scheme, pack a row and unpack it | the scheme builds and the row round-trips |

**Expected outcome**: every refused source gives `scheme_error`; every control builds and round-trips; a count that named a bool in Java, Rust and C++ is now refused (it was accepted); a float `when` in C# and TypeScript is now refused (it was accepted).
**Max execution time**: 1s

### FT-X-10: The pack stage of the hostile vectors

**Summary**: Five `pack` cases in `fixtures/hostile/cases.txt` give the same outcome in every package that can express them, and each package that cannot reports the case skipped with a reason (loop 18, AZ-2194).
**Traces to**: AZ-2194 AC-4, AZ-2194 AC-5, AZ-2194 AC-6, AZ-2194 AC-7, AZ-2194 AC-8
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 18 (wave 2); the file and its README pass FT-X-01

**Input data**: the five cases below (the scheme and the row are in the README section of each id, not in the file):

| Case | Scheme and row | Expected | Run by | Not run by |
|------|----------------|----------|--------|------------|
| `pack_out_of_range_integer` | `u8 a`; `a = 300` | `pack_error` (not wrapped to `2c`) | TypeScript, Python, Java, C# (dictionary rows), Rust (map form, `U16(300)`) | C++ (a typed row binds a `std::uint8_t`) |
| `pack_missing_required_value` | `u8 a; u8 b`; `a = 1` | `pack_error` | all six (C++: an unset `Opt` member gives `BadValue`) | none |
| `pack_times_list_too_long` | `u8 a; times(count a){ u8 x }`; `a = 2`, `x = [1, 2, 3]` | `pack_error` | all six | none |
| `pack_times_list_too_short` | same scheme; `a = 2`, `x = [1]` | `pack_error` | all six | none |
| `pack_aligned_round_row` | `repeat{ flags{ bool on, u8 n } }`; `on = [true, false, true]`, `n = [1, 2, 3]` | `bytes` `01030102020303` | all six | none |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | each package's vector test packs the row of every case in its `Run by` list | `pack_error`: pack throws (C#, Java, TypeScript, Python) or returns an error (Rust `PackError`, C++ `BadValue`) and returns no bytes; `bytes`: exactly the packet in the table |
| 2 | each package's vector test reaches a case in its `Not run by` list | the case is reported skipped with its reason; a package in `Run by` that cannot run its case fails |

**Expected outcome (loop 18)**: 25 of 25 cases pass in the packages that run them; the only skip is `pack_out_of_range_integer` in C++; the error type and message are not asserted; the 20 earlier cases (10 `unpack`, 8 `construct`, 2 `limit`) give the same results as before the stage existed.
**Loop 19 (AZ-2329, AZ-2331, AZ-2332, AZ-2335)**: seven more `pack` cases make 12: `pack_times_count_over_limit` and `pack_lone_bytes_in_round` (C++ skipped), `pack_times_zero_with_values`, `pack_split_when_source_after_byte`, `pack_split_times_count_after_byte` and `pack_split_times_count_skipped` (all six run them; `pack_error`), and `pack_split_false_condition_silent` (`bytes` `0100025a00`, all six). The loaders that replay them: `HostilePackVectorTests.PackCase_ReturnsTheBytesOrRefuses`, `hostile.test.ts` with `support/hostile-pack.ts`, `hostile_support.py` `PACK_CASES`, `HostileVectorTest.replayPack`, `hostile_tests.rs` `pack_case`, `hostile_host_tests.cpp` `pack_cases`. See FT-X-24, FT-X-26, FT-X-27, FT-X-30.
**Loop 20 (AZ-2354, AZ-2355, AZ-2356, AZ-2360, AZ-2367)**: seven more `pack` cases make 19 (the scheme and the row of each are in the README section of its id, with `Run by`, `Not run by` and `Source` lines that name each of the six packages exactly once between the two lines, as `check-cases.sh` requires):

| Case | Scheme and row | Expected | Run by | Not run by |
|------|----------------|----------|--------|------------|
| `pack_lone_utf8_under_times_over_budget` | `u32 n; times(count n){ utf8 s }`; `n` = 65 535, `s` = 65 535 x `a` | `pack_error` naming `s` (the packet would pass `maxBytes` 16 777 216 at round 256) | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (caller buffer, rounds in a fixed `Array`: no output budget) |
| `pack_element_times_over_budget` | `list items of group { u32 n; times(count n){ u64 k } }`; 40 items of `n` = 65 535, `k` = 5 | `pack_error` naming `k` (loop 20: item 33 passes `maxBytes`; since loop 22 the slots limit refuses it first, at item 17: `k: the rounds would hold 1048577 slots, above the limit of 1048576 slots`; the bytes route is `pack_element_times_over_bytes_budget`) | TypeScript, Python, Java, C# (dictionary rows) | Rust (a list element cannot hold a `times`), C++ (as above) |
| `pack_slots_over_limit` | `u32 n; times(count n){ 65 x u8 }`; `n` = 65 535, each member 1 | `pack_error` (4 259 775 slots over the default `maxSlots`, bytes stay under `maxBytes`; loop 20: 4 194 304, refused at round 64 528; since loop 22: 1 048 576, refused at round 16 132 with 1 048 580 slots) | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (fixed `Array` of rounds, no slot budget) |
| `pack_repeat_over_limit` | `repeat { u8 k }`; `k` = 65 536 x 7 | `pack_error` (one above the default `maxRounds`, refused before the first round) | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (rounds in a fixed `Array` of at most 65 535 items) |
| `pack_split_count_zero_after_byte_list` | split `flag_byte`; `u8 n` after the byte; bit 0 { `times`(count `n`){ `u8 pt` } }; `n` = 0, `pt` = `[5, 6]` | `pack_error` | all six (C++: an `Array` of two beside `n` = 0) | none |
| `pack_split_count_zero_after_byte_scalar` | same scheme; `n` = 0, `pt` = 5 (a lone scalar) | `bytes` `010000` | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (a typed row holds an `Array`) |
| `pack_flags_skipped_count_with_values` | `flags { u8 n; times(count n){ u8 pt } }`; `n` not given, `pt` = `[5, 6]` | `pack_error` naming `pt` | all six (C++: an `Array` of two with `n` unset) | none |

Replay: TypeScript `hostile.test.ts` with `support/hostile-pack.ts` (a `PACK_REFUSAL` table pins the message of the budget, repeat, slot and skipped-count cases, so a wrong-reason `RangeError` cannot pass), Python `hostile_support.py` `PACK_CASES`, Java `HostileVectorTest.replayPack`, C# `HostilePackVectorTests.PackCase_ReturnsTheBytesOrRefuses` (a member table pins `'S'`, `'K'`, `'M0'`, `'Pt'`), Rust `hostile_tests.rs` `pack_case` with a `PACK_NOT_RUN` skip table, C++ `hostile_pack_cases.hpp` with `kPackSkips`. Python, Java, Rust and C++ assert refusal only, not which rule fired (reviews B4, C5, loop 21). Run time: Python element case 7.1 s, Python slots 3.3 to 4.2 s, Rust debug slots 8.1 s, TypeScript slots 1.45 s, every other case under 1 s. See FT-X-38 to FT-X-41, FT-X-43 to FT-X-45, FT-X-52.
**Loop 21 (AZ-2394)**: fifteen more cases make 55 (see FT-X-65 in [blackbox-tests-14](blackbox-tests-14-loop21-slot-rule-and-parity.md)).
**Loop 22 (AZ-2417)**: ten more cases make 65 (7 `pack`, 3 `construct`; `check-cases.sh` ok: 65; scenario FT-X-73 in [blackbox-tests-15](blackbox-tests-15-loop22-parity-and-memory-bound.md)). The 55 older cases are unchanged except the texts that carry the default `maxSlots`, now 1 048 576:

| Case | Scheme and row | Expected | Run by | Not run by |
|------|----------------|----------|--------|------------|
| `pack_novalue_count_clear_when_bits` | `u8 mode; when mode==1 { u8 c }`; split bit { `bits v` count `c` }; `mode` 0, `c` 3, no `v` | `pack_error` (the count is above 0, no field wrote it, the member has no value) | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (loop 22 reason "a typed row has no 'no value'"; since loop 23: a member bound to an `Array` is always present and pack refuses it with `BadValue` at the member, while an unbound member packs the clear bit where the case expects `pack_error`, open U24; FT-X-77) |
| `pack_novalue_count_clear_when_packed` | same with `packed` (width 1, bias 0) | `pack_error` | as above | C++ |
| `pack_novalue_count_clear_when_sized` | same with `sized` | `pack_error` | as above | C++ |
| `pack_repeat_unequal_lists_lone` | `repeat { u8 a; u8 b }`; `a` [1,2], `b` 7 | `bytes` `0101070207` | TypeScript, Python, Java, C# (dictionary rows) | Rust (rounds as groups only), C++ (a typed `Array` of round items) |
| `pack_repeat_unequal_lists_when` | `repeat { u8 k; when k==1 { u8 v } }`; `k` [1,2], `v` [9] | `bytes` `01010902` | as above | Rust, C++ |
| `pack_times_short_list_flags` | `u8 c; times(c){ flags { u8 v } }`; `c` 2, `v` [5] | `bytes` `0102010500` | TypeScript, Python, Java, C# (dictionary rows), Rust (map form) | C++ (an `Array` with one item per round) |
| `pack_element_times_over_bytes_budget` | `list items of group { u32 n; times(n){ utf8 s } }`; 16 items of `n` 65 535, `s` 16 x `a` | `pack_error` (18 874 147 bytes pass `maxBytes` 16 777 216 in item 15; 1 048 560 slots stay under `maxSlots`) | TypeScript, Python, Java, C# (dictionary rows) | Rust (a list element cannot hold a `times`), C++ (no output budget) |
| `construct_empty_when_times_body`, `construct_empty_when_repeat_body`, `construct_empty_nested_when_body` | a `times` or `repeat` whose body is an empty `when`, or a `when` of an empty `when` (the `when` source sits outside the round) | `scheme_error` (C++: `SchemeInvalid`, AZ-2416) | six packages | none |

A package with a scope rule (Python, Java, C#, Rust) refuses the three `construct` cases by that rule before the empty-body rule; TypeScript reaches the empty-body rule through its public builder, and C++ runs its body rule (`check_shape`) before its scope rule (`resolve`), so in C++ the body rule fires first (loop 23, U21 A; loop 22 said C++ refused them "by its source check"). The case asserts `scheme_error` only and each package pins the empty-body rule in its own tests (review22 2); C++ pins it by direct `check_shape`/`has_member` calls since loop 23, because the source-less `eq(-1, ...)` it used before is now refused (U19, FT-X-75, FT-X-76). AZ-2412 (Rust refuses per-name `repeat` lists without groups) has no case: the other five packages pack those lists. Every loader also has a standing test that a wrong rule-table entry fails it (AZ-2418, FT-X-74). Skips at loop 22: C++ seven more `pack` cases (the three `pack_novalue_*`, both `pack_repeat_unequal_lists_*`, `pack_times_short_list_flags`, `pack_element_times_over_bytes_budget`), Rust three more (both `pack_repeat_unequal_lists_*`, `pack_element_times_over_bytes_budget`).
**Max execution time**: 5s
