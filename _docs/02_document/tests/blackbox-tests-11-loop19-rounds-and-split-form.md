# Blackbox Tests 11: Loop 19 rounds and the split flag byte (FT-X-24 to FT-X-30)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Loop 19 (`round-parity-and-construction-checks`, AZ-2329 to AZ-2342) made the six packages agree on round counts, the split `flag_byte` form, lone values in a round and `eq` constants. Test names were checked by grep in each package's test directory; hostile ids are in `fixtures/hostile/cases.txt` (33 cases after this loop, see FT-X-01 and FT-X-10). Package suites after the review fix pass: C# 913 (both targets), TypeScript 728, Python 777, Rust 533, Java and C++ green.

### FT-X-24: Pack refuses a `times` count above `maxRounds` before it writes a round

**Summary**: Pack of a `times` whose count is above the scheme's `maxRounds` (default 65 535) returns an error naming the first body member and no bytes, with no allocation proportional to the count; a count at the limit still packs; a scheme that raised the limit packs a larger count (loop 19, AZ-2329).
**Traces to**: AZ-2329 AC-1, AZ-2329 AC-2, AZ-2329 AC-3
**Category**: Errors

**Preconditions**:
- C#, TypeScript, Python, Java and Rust as built in loop 19; C++ packs into a fixed `Array` of at most 65 535 items, so a count of 65 536 is refused only as a count that differs from the array length

**Input data**: `u32 n; times(count n){ u8 x }` with `n` = 65 536, 70 000, 2 000 000 000, 4 000 000 000 and `x` a lone scalar; `n` = 65 535 with one scalar; the same scheme with `maxRounds` 70 000 and `n` = 70 000; `u64 n` = 4 294 967 299 and 4 294 967 296 (Java review B1: the count was cut to 32 bits before the check); a `times` inside `flags`, inside a round and inside a list element

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each count above the limit | an error naming the member (Java: `times: count 65536 is above the limit of 65535 rounds`); no bytes; the 4 billion count returns at once |
| 2 | pack `n` = 65 535 and unpack the result | 5 + 65 535 bytes (Java: first bytes `01ffff000007`); the row round-trips |
| 3 | pack `n` = 70 000 with `maxRounds` 70 000; pack with a lowered limit | packs without error; a scheme with `maxRounds` 3 refuses a count of 4 |
| 4 | replay `pack_times_count_over_limit` (hostile `pack` stage) | `pack_error` in five packages; C++ skipped with its reason |

**Expected outcome**: step 1 is an error in five packages, also for the u64 counts 2^32 + 3 and 2^32 (they packed three rounds and zero rounds before review B1); steps 2 and 3 give the bytes of today. Tests: C# `PackRoundCapTests.Ac1_*`, `Ac2_*`, `Ac3_*`; TypeScript `pack-round-count-cap.test.ts`; Python `test_pack_round_count_cap.py` (`test_ac1_*`, `test_ac2_*`, `test_ac3_*`); Java `RoundLimitsTest.packRefusesACountAboveTheLimit` (cases "AZ-2329 AC-1", "loop 19 B1"); Rust `pack_round_cap_tests.rs` (`ac1_*`, `ac2_*`, `ac3_*`). Not specified: a `repeat` given more than `maxRounds` list entries still packs and its unpack is then refused (assessment U1, open owner question); Rust caps `max_rounds` only, not `max_slots` (review A5). Upgrade note: a scheme built with a low limit can no longer pack a count above it.
**Max execution time**: 1s

### FT-X-25: Python rounds use a fresh scope in pack and unpack

**Summary**: A Python `repeat` or `times` round does not see a value an earlier round wrote, as TypeScript does (loop 19, AZ-2330).
**Traces to**: AZ-2330 AC-1, AZ-2330 AC-2, AZ-2330 AC-3
**Category**: Bytes

**Preconditions**:
- Python as built in loop 19; the T1 row of the loop 18 review was not found, so the worker built an equivalent scheme

**Input data**: `u8 a; times(count a){ u8 k, when(k == 1) { u8 v }, when(v == 5) { u8 w } }` with `a` = 2 and the rounds the TypeScript run used; the same shape in a `repeat`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the row in Python and in TypeScript | the same hex, `010201050700` (Python raised `TypeError` before); the spec text says `010201050100` (see below) |
| 2 | unpack that hex in Python | the row TypeScript returns |
| 3 | unpack then repack 20 000 random packets against a HEAD copy | repeat and times repack counts equal (1 542 and 17 124); the schemes that read a stale value now raise `ValueError` |
| 4 | run the Python suite, golden and ring | unchanged |

**Expected outcome**: steps 1 and 2 give the TypeScript result; step 4 passes without edits. Tests: Python `test_round_fresh_scope.py` (`test_ac1_times_round_does_not_see_a_value_an_earlier_round_wrote`, `test_ac1_repeat_*`, `test_ac1_a_stale_value_in_the_skipped_slot_is_not_written`, `test_ac2_*`, `test_unpacked_bytes_repack_to_the_same_bytes_or_are_refused`). Note: the AZ-2330 text names `010201050100` while the worker's equivalent scheme gives `010201050700` in both languages; the exact T1 row is not in the repo, so AC-1 is covered by the equivalent. Upgrade note: Python bytes change for a scheme whose later round read a stale value.
**Max execution time**: 1s

### FT-X-26: A split flag-byte pack is loud when the bit cannot carry a body, silent when the condition is false

**Summary**: With a split `flag_byte`, pack fails naming the member when a `when` source or a `times` count is written after the byte (or the count is skipped) and a body is given that would be written; a false condition with a body given packs without the body and without an error; the combined `flags` form and sources before the byte are unchanged (loop 19, AZ-2331; AC-3 decided by the owner on 2026-10-11, option A).
**Traces to**: AZ-2331 AC-1, AZ-2331 AC-2, AZ-2331 AC-3, AZ-2331 AC-4
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 19, including the review fix pass (C# A1 and A3, Rust A2, TypeScript B2 and B7, Python B5, Java B9, C++ C1)

**Input data**: the hostile cases below (schemes and rows are in the README sections); the loop 18 reference rows with the source before the byte

| Case | Row | Expected |
|------|-----|----------|
| `pack_split_when_source_after_byte` | `mode = 1`, `speed = 7` (`mode` written after the byte) | `pack_error` naming `speed` |
| `pack_split_times_count_after_byte` | `n = 2`, `pt = [5, 6]` (`n` written after the byte) | `pack_error` |
| `pack_split_times_count_skipped` | `sel = 0`, `pt = [5]` (the `when` that writes `n` is false) | `pack_error` naming `pt` |
| `pack_split_false_condition_silent` | `mode = 0`, `speed = 7`, `heading = 90` | `bytes` `0100025a00` |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the three loud cases in each package | a pack error (C#, Java, TypeScript, Python throw; Rust `PackError`; C++ `BadValue`) and no bytes |
| 2 | pack the false-condition row with the source before the byte and after it | `0100025a00` in all six; `0102005a00` when the source is written after the byte with `mode` 0 (C# probe) |
| 3 | pack the loop 18 reference rows with the source before the byte, and the combined `flags` form | the bytes of loop 18, unchanged |
| 4 | pack review shapes: C# count 0 written before the byte with a lone scalar and `Heading` 90; Rust source absent from the row; TypeScript skipped count under a `when` in a split bit; Python two `when`s in one bit; C++ count inside the bit body | `0100025a00` (C#); silent (Rust); error (TypeScript, Python); packs as before (C++) |

**Expected outcome**: step 1 is an error in six packages; step 2 gives the bytes above in six (the AC-3 table of the batch report: C# and Rust applied AC-3 literally first, then all six were aligned to option A); steps 3 and 4 as stated. Tests: C# `SplitFormDroppedBodyTests.Ac1_*`, `Ac2_*`, `Ac3_*`, `Ac4_*`; TypeScript `split-form-loud-pack.test.ts`; Python `test_split_form_pack_fails_loudly.py`; Java `SplitFormLoudPackTest` (`ac1ConditionWrittenAfterTheByte`, `ac2CountWrittenAfterTheByteOrNeverWritten`, `ac3ConditionFalseOnWrittenValuesStillDropsTheBody`, `ac4SourceBeforeTheByteIsUnchanged`, `loop19B9CountSkippedBehindFlagsInASplitBit`); Rust `split_form_loud_tests.rs`; C++ `split_form_loud_host_tests.cpp` (`ac1_*`, `ac2_count_never_written`, `ac4_*`) and `late_source_host_tests.cpp` (`c1_*`, `c9_distance_over_255_is_refused_at_construction`); the four hostile cases through the six loaders. Not specified (loop 20): a skipped count in the combined `flags` form is loud in Python only (B6); C++ still lets rounds through when the count is set in the row behind a clear `when` (`010003055a00`, +56 B flash of a 128 B margin); a `times` written after the byte with value 0 and values given errors in C# and Rust only (assessment U2); C++ records only the first late `when` of a bit (C2).
**Max execution time**: 1s

### FT-X-27: A lone byte buffer in a round is refused

**Summary**: A single byte buffer given for a `Bytes` or `Sized` name in a `times` or `repeat` round is refused naming the member instead of being broadcast to every round; a list with one buffer per round packs as before (loop 19, AZ-2332; closes the open question of FT-X-11).
**Traces to**: AZ-2332 AC-1, AZ-2332 AC-2
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java and Rust as built in loop 19; C# already refused it (AZ-2182); C++ holds a typed `Array` of `Array`, so a lone buffer cannot be written

**Input data**: `u8 n; times(count n){ bytes(2) d }` with `n = 2` and `d` = one buffer `0102`; the list `[0102, 0304]`; a `sized` name; one-round `times`; a `repeat`; a lone `utf8` string for a `utf8` name; a lone `byte[]` under a count-0 `times` member of `flags` (Java review B4)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the lone buffer in each package | an error naming `d`; no bytes (also for count 1, for `sized`, and under a `flags` member) |
| 2 | pack the list of two buffers | `010201020304`; unpack and repack gives the same bytes |
| 3 | pack the lone `utf8` string; pack a bytes field outside a round | the string goes to every round, as before; one buffer outside a round packs |
| 4 | replay `pack_lone_bytes_in_round` | `pack_error` in five packages; C++ skipped with its reason |

**Expected outcome**: step 1 is an error in five packages (C# already); steps 2 and 3 unchanged. Tests: TypeScript `lone-bytes-in-round.test.ts`; Python `test_lone_bytes_in_round_refused.py` (`test_ac1_*`, `test_ac2_*`); Java `LoneBytesInRoundTest.ac1LoneBufferIsRefused`, `ac2OneBufferPerRoundPacks`, `SplitFormLoudPackTest.loop19B4LoneBufferUnderACountZeroFlagsTimes`; Rust `lone_bytes_in_round_tests.rs` (`ac1_*`, `ac2_*`); C# `LoneRoundValueTests.Pack_LoneCollectionInARound_ThrowsNamingTheField`. Upgrade note: callers that relied on the broadcast break (owner decision 4); Rust's `Value::Bytes` is refused even with count 1. Not specified: a lone `bits` or `packed` value in Java cannot be told from a list.
**Max execution time**: 1s

### FT-X-28: Rust sibling `flags` members each have their own flag-byte scope

**Summary**: Two sibling `flags` members that each hold a `flag_byte(0)` and bits pack in Rust to the TypeScript bytes; before this loop the second member bound to the first member's byte (loop 19, AZ-2333).
**Traces to**: AZ-2333 AC-1, AZ-2333 AC-2
**Category**: Bytes

**Preconditions**:
- Rust as built in loop 19; the reference is a TypeScript run on scheme S1

**Input data**: S1 = `flagbyte fb; flags{ group g1{ v; fb byte; bit fb x }, group g2{ bit fb y } }; bit fb b`; rows `v3 x5 y6 b7`, `v3 x5`, `y6`, `b7`, `v3 y6`; S2 = the same without the outer byte; one `flags` member with a byte of its own

| Row | Rust before | TypeScript and Rust after |
|-----|-------------|---------------------------|
| `v3 x5 y6 b7` | `0101030303050607` | `0103030301050607` |
| `v3 x5` | `010001030105` | `010001030105` |
| `y6` | `010002` | `01010206` |
| `b7` | `01010007` | `01020007` |
| `v3 y6` | `010003030206` | `010103030006` |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack each row of S1 in Rust | the hex of the right-hand column |
| 2 | unpack each hex and repack | the same bytes |
| 3 | build S2 in Rust | refused at construction, as TypeScript does |
| 4 | pack a scheme with a single `flags` member | bytes unchanged |

**Expected outcome**: steps 1 and 2 give the TypeScript bytes; step 3 is a construction error; step 4 is unchanged. Tests: Rust `flags_member_scope_tests.rs` (`ac1_sibling_members_each_have_their_own_byte_scope`, `ac1_a_bit_in_a_sibling_member_cannot_use_the_byte_of_the_member_before`, `ac1_a_byte_that_is_itself_a_flags_member_is_not_seen_by_the_next_member`, `ac2_*`). Java and C++ were not run on S1 (C++ single-member table pinned in FT-X-15). Upgrade note: Rust bytes change for sibling members that shared a byte (owner decision 5).
**Max execution time**: 1s

### FT-X-29: C++ takes an empty group as a `when` source

**Summary**: C++ accepts `eq(emptyGroup, true)` as a `when` condition and packs the Rust bytes; `eq` of anything other than `true` on an empty group is refused; a field that has the id of an empty group stays the source (loop 19, AZ-2334; review C8).
**Traces to**: AZ-2334 AC-1
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 19 (host and the arm embedded stage)

**Input data**: a scheme with an empty group followed by `when(eq(group, true)) { u8 v }`, `v` = 7; `eq(emptyGroup, false)`; `flags(0, group(0))` then a field of id 0 that is not a counted source, then a `when`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the scheme, pack with the group present and absent, unpack | `010107` (on) and `0100` (off), equal to Rust's `when_written_tests.rs` row (read, not run); the rows round-trip |
| 2 | build `eq(emptyGroup, false)` | refused (`SchemeInvalid`) |
| 3 | build the same-id scheme | the field with the id of the empty group stays the source; no silent bind to the group |
| 4 | run the arm embedded stage | stack 448 B of 512; flash 8064 B of 8192 |

**Expected outcome**: step 1 gives the hex above; step 2 refuses; step 3 keeps the earlier rule; step 4 within budget. Tests: C++ `source_kinds_host_tests.cpp` (`eq_on_an_empty_group_builds_and_round_trips`, `eq_on_an_empty_group_other_than_true_is_refused`, `a_field_with_the_id_of_an_empty_group_stays_the_source`); `late_source_host_tests.cpp` (`c8_same_id_field_blocks_the_empty_group_fallback`, `c8_empty_group_alone_is_still_the_source`). Not specified: an empty group takes the id of the next field (documentation note).
**Max execution time**: 1s

### FT-X-30: A `times` count of 0 with values is an error; a lone scalar with count 0 is not

**Summary**: A `times` with count 0 and a list that holds a value is refused naming the member in all six packages; count 0 without values writes zero rounds; a lone scalar with count 0 packs `0100` and drops the value in all six, a documented parity (loop 19, AZ-2335; owner decision 7 and point 1).
**Traces to**: AZ-2335 AC-1, AZ-2335 AC-2
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 19; all six packages already refused a list with count 0 (batch report: tests only), so this loop added the tests and the hostile case

**Input data**: `u8 a; times(count a){ u8 x }` with `a = 0`, `x = [5]`; `a = 0` with `x = []` and with `x` absent; `a = 0` and a lone scalar `x = 5`; the same under `flags` and in the split form; count 0 with a value outside the member's range

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack `a = 0`, `x = [5]` | an error naming `x`; no bytes (C++ `BadValue`) |
| 2 | pack `a = 0` with an empty or absent list | `0100`: zero rounds |
| 3 | pack `a = 0` with a lone scalar | `0100`, no error, the value dropped |
| 4 | replay `pack_times_zero_with_values` | `pack_error` in all six, C++ through an `Array` of one item |

**Expected outcome**: step 1 is an error in six (C# and Rust also in the split form, before and after the byte; a value outside the range is still named); step 2 `0100`; step 3 `0100` in all six. Tests: C# `TimesZeroWithValuesTests.Ac1_*`, `Ac2_*`; TypeScript `times-count-zero-with-values.test.ts`; Python `test_times_count_zero_with_values.py`; Java `TimesCountZeroTest.ac1CountZeroWithValuesIsRefused`, `ac2CountZeroWithoutValuesPacks`; Rust `times_count_zero_tests.rs`; C++ `times_count_zero_host_tests.cpp` (`ac1_count_zero_with_a_value_is_refused`, `ac2_count_zero_without_values_packs`, `a_lone_value_with_count_zero_is_unchanged`). Not specified: the lone scalar silently dropped (owner point 1: leave and document).
**Max execution time**: 1s
