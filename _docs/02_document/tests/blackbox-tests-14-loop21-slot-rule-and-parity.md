# Blackbox Tests 14: Loop 21 one slot rule, parity rules and empty round bodies (FT-X-53 to FT-X-65)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Loop 21 (`parity-rules-and-round-cpu-bound`, AZ-2373 and AZ-2381 to AZ-2394) gave a round one slot-width rule in the six packages, aligned seven pack rules (owner decisions U1 to U9 of 2026-10-12, option A), made C# return exact integer types and bind rounds to rows, refused an empty `times` or `repeat` body at build (security F33), removed a quadratic copy in the TypeScript round scope (F34), pinned the rule that refuses each hostile `pack` case, and added 15 hostile cases (55 in all). Hex, texts and row numbers come from `_docs/03_implementation/reference_loop21_slots.md` (TypeScript is the reference; rows 1 to 56) and were checked against the test files by grep. Test names are the real ones. Commit under test: `3acc589`; the one total run of the loop is `_docs/03_implementation/test_run_loop21_report.md`.

**Per-package error type** (the outcome and the numbers are equal; the type and the way a member is quoted differ; message parity is out of scope, owner decision U10 option B): TypeScript `RangeError`, Python `ValueError` (`RuntimeError` for a counted member whose count is missing), Java `IllegalArgumentException` (`IllegalStateException` for a missing count), C# `ArgumentException` (members quoted: `'B'`), Rust `PackError` (a build panic for a refused scheme), C++ `BadValue` on pack and `SchemeInvalid` at construction. A package whose text differs in a way the tests pin is named in the scenario.

**Packages that skip a row, and why** (one place for all scenarios): **C++** has no slot budget and no `repeat`/`times` rounds beyond a fixed `Array`, so the four `pack_round_slots_*` cases, `pack_flags_short_list` (a fixed `Array` of round items: a short list cannot be written) and `pack_split_times_absent_body` (a count of 2 with an empty `Array` is a count mismatch, refused by the late rule; AZ-2384 excludes C++) are skipped, and so is the `construct` case with a list element. **Rust** skips `pack_flags_short_list` (a `repeat` takes its rounds as groups, one row per round) and the list-element `construct` case (a list element cannot hold a `times`). Python never builds an empty group, so slot row 1 uses a `flags` `bool`. The hostile case file after loop 21: 55 cases (10 `unpack`, 12 `construct`, 2 `limit`, 31 `pack`); C++ runs 38 and skips 17; Rust runs 52 and skips 3; TypeScript, Python, Java and C# run all 55.

Package suites at the total run (commit `3acc589`): C# 1479 on net10.0 and the same 1479 on netstandard2.0, TypeScript 880, Python 1003, Rust 625, Java `PackbinTest` 2153 checks, C++ gcc:16 and host green, 0 failed; arm embedded stage PASS. The loop 20 counts were C# 1118, TypeScript 765, Python 846, Rust 569, Java 1952.

### FT-X-53: One slot-width rule for a round, on pack and on unpack, in the same count in every package

**Summary**: A round charges `maxSlots` the number of distinct names it can hold, as it starts and before any byte of it; a packet pack writes at exactly `maxSlots` unpacks in the same package (Python no longer charges 8 more slots per name for the first round of each run); the third round is refused with the same numbers in pack and unpack (loop 21, AZ-2381, AZ-2382, decisions U1 and U2).
**Traces to**: AZ-2382 AC-1, AZ-2382 AC-2, AZ-2381 AC-1, AZ-2381 AC-2
**Category**: Errors

**Preconditions**:
- TypeScript (reference, no code change), Python, Java, C# (dictionary and typed rows) and Rust as built in loop 21; C++ skipped (no slot budget)

**Input data**: `new Scheme(1, [repeat(0, BODY)], { maxSlots: 2W })`; W = distinct names of the body: an empty group's name, each `u2` slot, `list` and `dict` names, the members of a `when`, `flags`, a flag bit and a group count; not counted: a non-empty group's own name, `flags`, the combined flag byte, a split `flagByte`, the anchors; a name that two `when`s declare is one slot. Reference rows 1 to 10 (hex is the whole packet):

| Row | Body | W | 2 rounds at `maxSlots` 2W | 3-round packet at `maxSlots` 3W |
|-----|------|---|---------------------------|---------------------------------|
| 1 | `u8 a; flags { group g {} }` | 2 | `0101010200` | `01010102000301` |
| 2 | `u8 m; when m==1 { u8 k }; when m==2 { u8 k }` | 2 (`k` once) | `0101070208` | `01010702080109` |
| 3 | `flags { bool on; u8 v }` | 2 | `0103050306` | `01030503060307` |
| 4 | split `flagByte m; bit { u8 a }; bit { u8 b }` | 2 | `01030104030205` | `01030104030205030306` |
| 5 | `u8 m; when m==1 { u8 k }`, `m` = 0, 0 | 2 (`k` charged, never written) | `010000` | `01000000` |
| 6 | `u8 a; group(1) g { u8 b; group(2) h { u8 c } }` | 3 | `01010407020508` | `01010407020508030609` |
| 7 | `u8 a; group g { u8 b }` | 2 | `0101040205` | `01010402050306` |
| 8 | `u8 a; u2 p, q, r` | 4 | `0101390239` | `01013902390339` |
| 9 | `u8 n; list l of u8; dict d of u8` | 3 | `010102000001010001006b000202000102010001006b01` | `010102000001010001006b000202000102010001006b010302000203010001006b02` |
| 10 | `u8 n; bytes(2) b; sized s` | 3 | `010100000901010109` | `01010000090101010901020209` |

Times and one counter (rows 11 to 14): `u8 n; times(n){ u8 m; when { u8 k }; when { u8 k } }` (W 2) with `maxSlots` 4: `n` 2 packs `010201070208`; `n` 3 is refused `m: the rounds would hold 6 slots, above the limit of 4 slots`. `u8 n; times(n){ u8 a }; repeat { u8 b }` with `maxSlots` 3: `n` 1, `a` [1], `b` [2, 3] packs `0101010203`; `b` [2, 3, 4] is refused `b: the rounds would hold 4 slots, above the limit of 3 slots`.

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the 2-round row of each shape at `maxSlots` 2W | the hex of the third column; no error |
| 2 | pack the 3-round row at `maxSlots` 2W | the first name the round holds is named: `a: the rounds would hold 6 slots, above the limit of 4 slots` (row 1; 9 vs 6 for row 6, 12 vs 8 for row 8); no bytes; the same row packs with `maxSlots` 3W to the fourth column |
| 3 | unpack the 3-round packet with the 2W scheme | TypeScript `{ok: false, field: "a", needed: 0, left: 2}` (row 1): refused at the round pack refuses; a split `flagByte` name comes first in an unpack error (row 4: field `m`), the numbers are the same |
| 4 | unpack the 2-round packet, pack the result again | `{ok: true}` and the same hex (Python: this is the case U1 closed; before, Python's own unpack refused its own packet) |
| 5 | rows 11 to 14 | the outcomes above; one counter runs through the whole call and is shared by every `repeat` and `times` |
| 6 | replay `pack_round_slots_at_limit`, `pack_round_slots_over_limit`, `pack_round_slots_flags_at_limit`, `pack_round_slots_flags_over_limit` | bytes `0101010203`, `pack_error`, bytes `0103050306`, `pack_error` in five packages; C++ skipped with its reason |

**Expected outcome**: all steps as above in five packages with equal hex and equal slot numbers. Tests: TypeScript `round-slot-width.test.ts` (`describe` "AZ-2382 a repeat round is charged the names it holds, on pack and unpack": "AC-1 two rounds charge ... and pack at maxSlots", "AC-1 a third round would hold ... slots and is refused at maxSlots", "AC-1 the same third round packs at maxSlots", "AC-2 the packet written at maxSlots unpacks and packs again to the same bytes", "AC-2 unpack refuses the third round at the round where pack refuses it", and "AZ-2382 times charges the same width as repeat, one counter for the whole call", three tests); Python `test_round_slot_width.py::test_ac1_a_round_charges_the_reference_width_two_rounds_pack_at_the_limit`, `test_ac1_the_third_round_is_refused_naming_the_first_name_and_the_slots_it_would_hold`, `test_ac1_three_rounds_pack_at_three_widths`, `test_ac1_unpack_refuses_the_third_round_with_the_bytes_the_reference_leaves`, `test_ac2_the_packet_pack_writes_at_the_limit_unpacks_and_packs_again_to_the_same_bytes`, `test_row1_*`, `test_row2_a_name_that_two_whens_declare_is_one_slot_not_two`, `test_row11_*` to `test_row14_*`, `test_ac2_unpack_of_the_times_and_repeat_row_charges_what_pack_charges`, `test_ac2_one_over_at_the_limit_is_still_refused_by_pack` (AZ-2381 AC-1 and AC-2); Java `RoundSlotWidthTest.run` (`atTheLimit`, `oneRoundOver`, `unpackAgrees`, `timesAndOneCounter`, `duplicateNamesAreOneSlotInUnpackToo`); C# `RoundSlotWidthTests.Ac1_*`, `Ac2_*`, `Times_Row11_*` to `Times_Row12_*`, `Counter_Row13_*`, `Counter_Row14_*` (dictionary rows) and `RoundSlotWidthTypedTests.Ac1_*`, `Ac2_*` (typed rows, member quoted `'B'`); Rust `round_slot_width_tests.rs::ac1_rows_1_to_10_*` (four tests), `ac2_rows_1_to_10_the_packet_written_at_the_limit_unpacks_and_packs_again`, `rows_1_to_10_one_slot_below_two_widths_refuses_the_second_round`, `row_11_*` to `row_14_*`. Open (owner row U16): Java counts an unanchored nested-row group as one slot where TypeScript counts its members (a group with two or more members differs; the one-member row 7 agrees). Wire bytes of accepted rows are unchanged.
**Max execution time**: 1s per package

### FT-X-54: A short list in an optional flags position of a `repeat` is refused; a full list packs as before

**Summary**: `repeat { u8 w; flags { u8 v } }` with `w` [1, 2] and `v` [5] used to pack `010101050200` in TypeScript; it is now refused before any round naming `v`, as Python already did; `v` [5, undefined] packs the old bytes (loop 21, AZ-2383, decision U3).
**Traces to**: AZ-2383 AC-1, AZ-2383 AC-2
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java and C# (dictionary rows); Rust and C++ skipped for the hostile case (see the header)

**Input data**: reference rows 27 to 39 (`repeat { u8 w; flags { u8 v } }` unless named):

| Row | Row value | Expected |
|-----|-----------|----------|
| 27 | `{w:[1,2], v:[5]}` | `v: 1 items, repeat count 2; give one entry per round, undefined where the member is absent`; no bytes |
| 28 | `{w:[1,2,3], v:[5, undefined]}` | `v: 2 items, repeat count 3; ...` |
| 29 | `{w:[1,2], v:[5, undefined]}` (also `null`) | packs `010101050200` |
| 30 | `{w:[1,2], v:[5,6]}` / `{w:[1,2]}` / `{w:[1,2], v:[]}` / `{w:[1,2], v:5}` | `01010105020106` / `0101000200` / `0101000200` / `01010105020105` |
| 32 to 36 | `bool on`; split bit; group member; `u2 p, q`; `when w==1` under `flags`, one entry short | `on: 1 items, ...`; `v: 1 items, ...`; `p: 1 items, ...` (the first short slot); `v: 1 items, ...` |
| 37 | `repeat { flags { u8 a; u8 b } }`, `{a:[1], b:[5,6]}` / `{a:[1,2,3], b:[5,6]}` | `a: 1 items, repeat count 2; ...` / `b: 2 items, repeat count 3; ...` |
| 38, 39 | `repeat { u8 k; when k==1 { u8 v } }` `{k:[1,2], v:[9]}`; `u8 c; times(c){ flags { u8 v } }` `{c:2, v:[5]}` | packs `01010902`; packs `0102010500` (not an optional flags position of a `repeat`: unchanged) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack rows 27, 28 and 32 to 37 in TypeScript, Python, Java, C# | an error naming the member and the numbers; no bytes |
| 2 | pack rows 29, 30, 38, 39 | the old bytes (row 29 is the bytes the short list used to give) |
| 3 | pack `{w:[1], v:[5,6]}` (row 31) | `missing w` (a required member keeps its own error) |
| 4 | replay `pack_flags_short_list` and `pack_flags_short_list_filled` | `pack_error` in four packages (Rust, C++ skipped); `010101050200` in all six (a typed C++ row with the `Opt` unset in round 2) |

**Expected outcome**: steps 1 to 4 as above. Tests: TypeScript `repeat-short-optional.test.ts` ("AC-1 the U3 row {w: [1, 2], v: [5]} is refused naming v, with no bytes", "AC-1 three rounds and two entries is refused the same way", "AC-1 a bool, a split bit, a group member, a u2 slot and a when under flags are refused the same way", "AC-1 in a combined flags the short member is the one named, whichever list is longer", "AC-2 the full list packs to the bytes the short list gave before", "AC-2 accepted rows keep their bytes: both entries, no entry, an empty list, a lone value", "AC-2 the bool full list packs and sets the bit only where it is true", and "AZ-2383 what the rule does not touch", four tests); Python `test_repeat_short_optional.py::test_ac1_row27_*` to `test_ac1_row37_*`, `test_ac2_row29_*`, `test_ac2_row30_*`, `test_ac2_row39_times_keeps_reading_a_short_list_under_flags_as_absent`; Java `RepeatShortOptionalTest.run` (`shortListsAreRefused`, `fullListsPackAsBefore`, `otherOptionalPositions`, `notOptionalPositionsAreUnchanged`); C# `ShortOptionalListTests.Ac1_Repeat_*` (eight tests) and `Ac2_*` (six tests). Rust: `loop21_parity_probes_tests.rs::az2383_rows_27_to_30_a_repeat_names_its_rounds_so_an_absent_member_is_a_round_without_it`, `az2383_row_27_per_name_lists_are_not_read_by_a_repeat_so_none_can_be_short`, `az2383_row_31_*`, `az2383_row_32_*`, `az2383_row_33_*`, `az2383_row_39_*` (probe; no error is raised). Open owner rows: U13 (Rust silently drops per-name `repeat` lists given without `__repeat__` groups and packs `01`), U14 (Python keeps the equal-length rule for a lone value, a short required list and a `when` list outside `flags`: `test_row30_row31_python_keeps_the_equal_length_rule_for_a_lone_value_and_a_short_required_list`, `test_row38_a_short_list_under_a_when_outside_flags_stays_refused_by_the_equal_length_rule`; the other five pack them), U15 (`times` keeps accepting a short list under `flags`; Rust refuses the list form). One accepted-row change inside TypeScript's tests: `round-values.test.ts` now gives `{a:[1, undefined], b:[5,6]}` for the same bytes `010301050206`.
**Max execution time**: 1s

### FT-X-55: A split-bit `times` with the count above 0 after the byte and no body packs a clear bit everywhere

**Summary**: `flagByte fb; u8 n; fb.bit(times(n){ u8 pt }); fb.bit(u16 heading)` with `n` 2 and no `pt` (or `pt` `[]`) packs `0102025a00` in TypeScript, Python, Java, C# and Rust; Java used to refuse it (loop 21, AZ-2384, decision U4). C++ refuses it by its late rule (AZ-2385) and is excluded.
**Traces to**: AZ-2384 AC-1, AZ-2384 AC-2
**Category**: Bytes

**Preconditions**:
- TypeScript, Python, Java, C# and Rust; C++ excluded

**Input data**: reference rows 40 to 43: `{n:2, heading:90}` and `{n:2, pt:[], heading:90}` pack `0102025a00` (flag byte `02`: bit 0 clear, bit 1 set; `n` 2; `heading` `5a00`); `{n:0, heading:90}` packs `0102005a00`; `{n:2, pt:[5,6], heading:90}` is refused (`pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte`)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack rows 40, 41, 42 | `0102025a00`, `0102025a00`, `0102005a00` |
| 2 | unpack `0102025a00` | `n` 2, `heading` 90, no `pt` (Java checks the unpack of the row 40 packet) |
| 3 | pack row 43 (a body given, the count written after the byte) | refused naming `pt`: the body cannot be decided by the byte (unchanged) |
| 4 | replay `pack_split_times_absent_body` | bytes `0102025a00` in five packages; C++ skipped with its reason |

**Expected outcome**: steps 1 to 4 as above. Tests: TypeScript `loop21-parity-probes.test.ts` ("AZ-2384 U4 ...": "AC-1 the body absent packs flag 02, n = 2, heading", "AC-1 the body [] packs the same bytes", "AC-1 count 0 after the byte with the body absent packs a clear bit too", "AC-2 the body present is refused: the count is written after the byte that decides the bit"); Python `test_loop21_parity_probes.py::test_az2384_ac1_rows40_to_42_a_count_after_the_byte_with_no_body_packs_a_clear_bit`, `test_az2384_ac2_row43_a_body_given_after_the_byte_is_refused`; Java `ClearBitProbesTest.u4SplitTimesCountAfterTheByte` (the change); C# `SplitTimesClearBitTests.Ac1_Pack_CountAboveZeroAndBodyAbsent_PacksAClearBit`, `Ac1_Pack_CountAboveZeroAndEmptyBody_PacksAClearBit`, `Ac1_Pack_CountZeroAndBodyAbsent_PacksAClearBit`, `Ac2_Pack_BodyGiven_IsRefusedNamingTheBody`; Rust `loop21_parity_probes_tests.rs::az2384_row_40_*` to `az2384_row_43_*`, `az2384_ac2_the_body_present_with_the_count_before_the_byte_is_unchanged`.
**Max execution time**: 1s

### FT-X-56: C++ packs a direct late `when` in a bit body when another member sets the bit, within the arm budgets

**Summary**: A flag bit whose body is a group `{ u8 d; when mode==1 { u8 a }; when mode==2 { u8 b } }`, with `mode` written after the flag byte, packs `0101010509` in C++ (and Rust) when `d` sets the bit; a bit held only by late members is still refused; the arm build stays inside 8 192 B of flash and 512 B of stack (loop 21, AZ-2385, decision U5, "only if it costs no flash").
**Traces to**: AZ-2385 AC-1, AZ-2385 AC-2
**Category**: Bytes

**Preconditions**:
- C++ (host and gcc:16, and the arm embedded stage), Rust; TypeScript, Python, Java and C# already packed the shape (probe) and replay the hostile case

**Input data**: `flagByte` written first; `u8 mode`; bit 0 { group { `u8 d`; `when mode==1 { u8 a }`; `when mode==2 { u8 b }` } }; rows: `mode` 1, `d` 5, `a` 9; `mode` 2, `d` 5, `b` 9; `mode` 3, `d` 5; `mode` 1 with only `a` 9

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack `mode` 1, `d` 5, `a` 9 | `0101010509` (flag byte `01`, `mode` 1, `d` 5, `a` 9) |
| 2 | pack `mode` 2, `d` 5, `b` 9; `mode` 3, `d` 5 | `0101020509`; `01010305` |
| 3 | pack `mode` 1 with only `a` 9 (no `d`); a late `times` beside `x` | `BadValue` naming the late `when` (the bit is held only by a late value, as `pack_split_when_source_after_byte`); a late `times` with `x` set packs `010102050708` |
| 4 | the arm embedded stage | Cortex-M4F flash 8152 of 8192 B (margin 40 B; 8160 B at loop 20), deepest pack/unpack stack 456 of 512 B (margin 56 B; 448 B at loop 20); M0+ PASS; M3 QEMU 241 of 241 vectors; s390x 241 of 241 |
| 5 | replay `pack_late_when_in_bit_body` | bytes `0101010509` in all six packages |

**Expected outcome**: steps 1 to 5 as above; the change was kept (the flash saving the spec required for a drop was not needed). Tests: C++ `late_source_host_tests.cpp::az2385_late_when_packs_when_another_member_sets_the_bit`, `az2385_nested_late_when_packs_when_another_member_sets_the_bit`, `az2385_late_times_packs_when_another_member_sets_the_bit` (and the loop 20 pins `az2364_every_late_when_of_a_bit_is_refused`, `az2364_link_over_255_is_refused_at_construction`, `az2357_hold_over_255_is_refused_at_construction` still pass); Rust `late_when_in_bit_body_tests.rs::ac1_the_readme_row_packs_with_the_other_member_setting_the_bit`, `ac1_the_second_late_when_packs_and_a_quiet_row_packs_without_either`, `ac1_a_late_when_in_a_nested_group_packs_with_the_other_member`, `ac1_a_late_times_packs_with_the_other_member_before_or_after_it`, `ac2_a_bit_held_only_by_late_whens_is_still_refused_naming_the_value`, `ac2_a_bit_held_only_by_a_late_times_is_still_refused_naming_the_value`, and `hostile_tests.rs::late_when_in_bit_body_packs_the_readme_bytes`; arm numbers: the `cpp-embedded` stage of the total run (`test_run_loop21_report.md`) and the batch 01 report. Known corner (review21 #7, handoff): C++ keeps one `Late` flag, so a refused id can be the wrong member.
**Max execution time**: 1s per test; the arm stage 8 s with a cached image

### FT-X-57: A count behind a clear `when` is refused when the packet cannot hold it, in all six packages

**Summary**: With the count written only when `mode == 1`, a row `mode` 0, `c` 1, no rounds used to pack `0100025a00` in TypeScript (and Python); it is refused naming the `times` (U6); the same rule holds for a `bits`, `packed` or `sized` member whose count is behind the clear `when` and that has a value (U7); count 0, a count left out, and a holding `when` pack as before (loop 21, AZ-2386, AZ-2387).
**Traces to**: AZ-2386 AC-1, AZ-2386 AC-2, AZ-2387 AC-1, AZ-2387 AC-2
**Category**: Errors

**Preconditions**:
- TypeScript (changed for U6, probe for U7), Python (changed for U6), Java, C# and Rust (probes, aligned); C++ already refused both (AZ-2357, review20 C2)

**Input data**: `u8 mode; when mode==1 { u8 c }; flagByte fb; fb.bit(times(c){ u8 pt }); fb.bit(u16 heading)`; the combined form `flags { times(c){ u8 pt }; u16 heading }`; the plain form `times(c){ u8 pt }; u16 heading`. Reference rows:

| Row | Row value | Outcome |
|-----|-----------|---------|
| 44 to 46 | `{mode:0, c:1, heading:90}` (also `pt: []`; `c:3n`) | `pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold` (`3` for row 46) |
| 47, 48 | `{mode:0, c:0, heading:90}`; `{mode:0, heading:90}` | packs `0100025a00` |
| 49 | `{mode:0, c:2, pt:[5,6], heading:90}` | the older text first: `pt: a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte` |
| 50 | the combined `flags` form, `{mode:0, c:2, heading:90}` | the row 44 text with `2` (packed `0100025a00` before); `c` 0 packs `0100025a00` |
| 51 | `{mode:1, c:1, pt:[5], heading:90}` | packs `01010103055a00` |
| 52 | the plain form, `c` 1 or 0 | `times: count c was not written` (unchanged; refused before and after) |
| 53 | `bits(v)`, `packed(v)`, `sized(v)` with count `c`, `{mode:0, c:3, v:[1,0,1]}` (`sized`: `010203`), plain, split bit and combined `flags` | `v: count c was not written` (nine rows) |
| 54, 55 | the same with `mode` 1 | plain `bits`/`packed` `01010305`, split `0101030105`; `sized` plain `010103010203`, split `01010301010203` |
| 56 | any of the three, `{mode:0, c:3}` with **no value**, split bit or combined `flags` | **packs `010000`** (a clear bit; nothing is dropped) at loop 21; refused since loop 22 (AZ-2410, FT-X-66) |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack rows 44 to 46 and 50 in the six packages | the row 44 text (TypeScript, Python, Java and Rust use it, Rust as a fragment; C++ answers `BadValue` naming the `times`, id 2); no bytes |
| 2 | pack rows 47, 48, 51 | the bytes above |
| 3 | pack rows 52 and 53 | refused in the six; Java `IllegalStateException` (`times: count 1 is missing`), Python `RuntimeError` (`2: count ... is missing`) for the counted kinds |
| 4 | pack row 56 | `010000` in the five packages that probe it at loop 21 (U11, decided in loop 22: refused for a count above 0, see FT-X-66) |
| 5 | replay `pack_count_one_clear_when`, `pack_bits_count_clear_when`, `pack_packed_count_clear_when`, `pack_sized_count_clear_when` | `pack_error` in six; the rule table of each loader names the member |

**Expected outcome**: steps 1 to 5 as above. Tests: TypeScript `loop21-parity-probes.test.ts` ("AZ-2386 U6 ...": "AC-1 count 1, body absent: refused naming the member, no bytes (packed 0100025a00 before)", "AC-1 count 1, body []: refused the same way", "AC-1 count 2 in the combined flags form is refused the same way", "AC-1 a bigint count above 0 is refused too", "AC-2 count 0 and the count left out pack as before", "AC-2 values given with the count never written keep their own error", "AC-2 a holding when packs the rounds as before", "AC-2 a plain times behind a clear when is refused at any count, as before"; "AZ-2387 U7 a bits/packed/sized count behind a clear when": "AC-1 plain, split bit and combined flags refuse the value, naming the member", "AC-2 a holding when packs as before", "observed: with no value given, a split bit or combined flags packs a clear bit"); Python `test_az2386_ac1_rows44_to_46_*`, `test_az2386_ac2_rows47_and_48_*`, `test_az2386_row49_*`, `test_az2386_ac1_row50_*`, `test_az2386_ac2_row50_*`, `test_az2386_row51_*`, `test_az2386_row52_*`, `test_az2387_ac1_row53_*`, `test_az2387_ac2_rows54_and_55_a_holding_when_packs`, `test_az2387_row56_no_value_behind_a_clear_when_packs_a_clear_bit`; Java `ClearBitProbesTest.u6CountBehindAClearWhen`, `u6TheWhenHolds`, `u7CountKinds`, `u7NoValueIsAClearBit`; C# `CountBehindClearWhenTests.Ac1_Pack_CountAboveZeroBehindAClearWhenInASplitBit_IsRefused`, `Ac1_Pack_CountAboveZeroBehindAClearWhenInATypedRow_IsRefused`, `Ac1_Pack_CountAboveZeroBehindAClearWhenInCombinedFlags_IsRefused`, `Ac2_Pack_CountZeroOrLeftOut_PacksAClearBit`, `Ac1_Pack_BodyGivenBehindASkippedCount_KeepsItsOwnRefusalFirst`, `Ac2_Pack_WhenHolds_PacksTheRounds`, `Ac1_Pack_PlainTimesBehindAClearWhen_IsRefusedWhateverTheCountInTheRow`, `Ac1_Pack_CountedMemberBehindAClearWhen_IsRefused`, `Ac2_Pack_CountedMemberWhenTheWhenHolds_PacksAsBefore`, `Ac3_Pack_CountedMemberWithNoValueBehindAClearWhen_PacksAClearBit`; Rust `count_behind_clear_when_tests.rs::az2386_row_44_*` to `az2386_row_52_*`, `az2386_the_refusal_reaches_a_times_through_a_group_and_a_when_that_holds`, `az2387_row_53_a_count_behind_a_clear_when_is_refused_for_all_three_kinds_in_all_positions`, `az2387_rows_54_and_55_*`, `az2387_row_56_*`; C++: the hostile handlers (`hostile_pack_loop21.hpp`, `kRefusals`: `BadValue` field 2) and the loop 20 pins `split_form_loud_host_tests.cpp::count_set_behind_a_clear_when`, `held_count_nested_late_host_tests.cpp::c2_*`. Open owner row U11: a `bits`/`packed`/`sized` count behind a clear `when` with **no value** packs `010000` in all six while the `times` shape with no value is refused (row 56 against row 44); the decision is refuse in six (A) or keep the clear bit (B).
**Max execution time**: 1s

### FT-X-58: C# unpack returns exact integer types, and an integer field refuses a whole-number float

**Summary**: C# unpack returns `byte`, `ushort`, `uint`, `sbyte`, `short`, `int`, `ulong`, `long` for integer fields (`double` before); pack refuses a `double`, `float` or `decimal` with a whole value (`5.0`) for an integer field naming it; `f32`/`f64` still take whole floats; a row unpack returned packs again to the same bytes (loop 21, AZ-2373; finishes AZ-2116 and the integer part of AZ-2358; wire bytes unchanged).
**Traces to**: AZ-2373 AC-1, AZ-2373 AC-2, AZ-2373 AC-3
**Category**: Bytes

**Preconditions**:
- C# (net10.0 and netstandard2.0), dictionary rows

**Input data**: `u8 A; u16 B (be); u32 C; i8 D; i16 E (be); i32 F; u64 G; i64 H; f32 I; f64 J`, packet `01 ff 0102 01000000 80 ff00 ffffffff ffffffffffffffff ffffffffffffffff 0000a040 000000000000f83f`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | unpack the packet | `A` byte 255, `B` ushort 258, `C` uint 1, `D` sbyte -128, `E` short -256, `F` int -1, `G` ulong max, `H` long -1, `I` double 5.0, `J` double 1.5 |
| 2 | unpack a `repeat` of `u16 B; i8 D` (`01 0100 ff 0200 7f`) and a `list` of `u32` (`01 0200 05000000 06000000`) | `ushort` 1, 2 and `sbyte` -1, 127; `uint` 5, 6 |
| 3 | pack the dictionary returned by step 1 | the same bytes; also for a `times` round `01 02 0100 ff 0203 7f` |
| 4 | set `A` to `5.0`, `5f`, `B` to `258.0`, `C` to `4294967295.0`, `D` to `-128.0`, `E` to `-2f`, `F` to `0.0`, `G` to `1.0`, `H` to `-1.0` or `A` to `5m` and pack | `ArgumentException` whose message starts `A:` (the member); no bytes |
| 5 | set `I` to `5.0` and `J` to `2f` and pack | packs; the tail is `0000a040` + `0000000000000040` |
| 6 | pack a whole `double` as a `repeat` round entry `[1, 2.0]` or a `list` element `[3.0]` of a `u8` | refused with `A:` |

**Expected outcome**: steps 1 to 6 as above. Tests: C# `ExactIntegerTypeTests.Ac1_Unpack_IntegerFields_ReturnTheirExactTypes`, `Ac1_Unpack_IntegerFieldsInRoundsAndElements_ReturnTheirExactTypes`, `Ac3_Pack_UnpackedRowOfEveryKind_GivesTheSameBytes`, `Ac3_Pack_UnpackedRounds_GiveTheSameBytes`, `Ac2_Pack_WholeDoubleOrFloatForAnIntegerField_IsRefusedNamingTheField` (nine rows), `Ac2_Pack_WholeDecimalForAnIntegerField_IsRefusedNamingTheField`, `Ac2_Pack_WholeFloatsForFloatFields_StillPack`, `Ac2_Pack_WholeDoubleInARepeatRoundOrListElement_IsRefused`; `StrictNumberTests.Pack_WholeFloatForAnInteger_ThrowsNamingTheMemberAndKind`, `Pack_WholeNumberForAFloat_StillPacks`, `Pack_RowReadByUnpack_PacksAgainToTheSameBytes`. The spec said 37 existing tests failed when integer fields refused floats; 7 failed (batch report row 10, a spec text to correct at step 13); the tests that asserted doubles now assert the exact types. Gap: the spec names typed rows, but a typed row holds a statically typed property, so no test puts a whole float in an integer field of a typed row (the loop 20 note on AZ-2358 AC-2 "typed rows" stays). Open owner row U12: a `List<double>` for an integer list builds and unpacks but pack refuses (review21 #1).
**Max execution time**: 1s

### FT-X-59: A typed C# `Repeat` or `Times` binds to a collection of rows; the scheme builds if and only if typed unpack binds it

**Summary**: A typed `Times`/`Repeat` whose member is `List<Row>`, `Row[]`, `IList<Row>` or `List<Row?>` packs one row per round and unpack builds one row per round; any other member type is refused at construction naming the member, by the same predicate typed unpack uses; the older bindings (object-typed or collection-of-collection members) still build (loop 21, AZ-2388, decision U8; the Go package will copy this model).
**Traces to**: AZ-2388 AC-1, AZ-2388 AC-2, AZ-2388 AC-3
**Category**: Bytes

**Preconditions**:
- C# (net10.0 and netstandard2.0)

**Input data**: `u8 N; times(0){ i32 Lat; i32 Lon }` bound to `List<Point> Points`; `u8 Tail`; packet `01 02 0a000000 14000000 1e000000 28000000 07` (Points (10, 20), (30, 40); Tail 7). A `Repeat` over the same members: `01 01000000 02000000 fdffffff 04000000` (rows (1, 2), (-3, 4)). Member types probed by the construction tests (20 types, each as `Times` and `Repeat`)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the row (N 2, two points, Tail 7) | the packet above |
| 2 | typed unpack the packet | `N` 2, `Tail` 7, two `Point` rows with the values above; zero rounds give an empty collection, a null collection packs as no rounds (`01 00 00`) |
| 3 | build the scheme with each member type | `List<Seat>`, `Seat[]`, `IList<Seat>`, `List<Seat?>` build and unpack two rounds as `10,11`; `ICollection<Seat>`, `IReadOnlyList<Seat>`, `IEnumerable<Seat>`, `HashSet<Seat>`, `Seat[,]`, `Seat[][]`, `IList`, `List<object>`, `object`, `List<int>`, `List<Value>`, `Seat`, `string`, `byte` do not build and do not unpack; for `HashSet<Seat>`, `IList`, `List<int>`, `List<Value>` and `Seat` the message starts `'Items': ` and names `E[], List<E> or IList<E>` |
| 4 | build with `List<NoDefault>` or `List<Abstract>` | `'Items': row type NoDefault needs a public parameterless constructor to be unpacked` |
| 5 | declare a round field for another row type | `'Tail' is declared for row type Route, but this scheme is for Point` |
| 6 | pack a `times` count that differs from the rows (3 against 2; 0 against 2) or rounds above the limits | `'Points': the times count is 3, but it holds 2 rounds`; `... is 0, but it holds 2 rounds`; `'Points': the repeat count is 2, above the limit of 1 rounds`; `'Points': the rounds would hold 4 slots, above the limit of 3 slots`; typed unpack above a limit returns the error result |
| 7 | the old binding: a round bound to list members (`Dict` form keeps per-name lists) | still builds and unpacks (`Ac3_Scheme_OldBindingOfARoundToListMembers_StillBuildsAndUnpacks`) |

**Expected outcome**: steps 1 to 7 as above. Tests: C# `RowRoundTests.Ac1_Pack_TimesOverAListOfRows_PacksTheRoundsOfEachRow`, `Ac1_Unpack_TimesOverAListOfRows_BuildsOneRowPerRound`, `Ac1_Pack_RepeatOverAListOfRows_RoundTripsWithTheSameBytes`, `Ac1_Scheme_BuiltFromFieldsOfT_PacksTheSameAsTheStaticForm`, `Ac1_Pack_ArrayAndIListMembers_RoundTrip`, `Ac1_Pack_ElementMembersNamedLikeTheRowAround_StayInTheirOwnRound`, `Ac1_Pack_OptionalMemberOfTheElementUnderFlags_KeepsItsOwnRound`, `Ac1_Pack_RoundInsideANestedRow_RoundTrips`, `Ac1_Pack_RoundInsideFlags_SetsTheBitOnlyForRows`, `Ac1_Unpack_NoRounds_GivesAnEmptyCollection`, `Ac1_Pack_NullCollection_IsNoRounds`, `Ac1_Pack_TimesCountDifferentFromTheRows_IsRefusedNamingTheMember`, `Ac1_Pack_ZeroCountWithRows_IsRefusedNamingTheMember`, `Ac1_Pack_RoundsAboveTheLimits_AreRefusedBeforeAnyRoundIsWritten`, `Ac1_Unpack_RoundsAboveTheLimit_ReturnTheErrorResult`, `Ac1_Pack_DictionaryFormOfARowRound_KeepsThePerNameLists`, `Ac2_Scheme_RoundFieldsDeclaredForAnotherRow_AreRefused`, `Ac3_Scheme_OldBindingOfARoundToListMembers_StillBuildsAndUnpacks`; `RowRoundMemberTests.Ac2_Scheme_RoundMember_BuildsIfAndOnlyIfTypedUnpackBindsIt` (20 types x 2), `Ac2_Scheme_MemberThatIsNotACollectionOfRows_IsRefusedNamingTheMember`, `Ac2_Scheme_RowTypeUnpackCannotCreate_IsRefusedNamingTheType`. Gap: the spec's blackbox row (a C# row round through the `language-pair.sh` ring, bytes equal to the other five) has no driver: `.github/workflows` was not changed in loop 21; the ring ran and passed (107 s) without a row-round case. The typed and dictionary forms give equal bytes inside C# (`Ac1_Scheme_BuiltFromFieldsOfT_PacksTheSameAsTheStaticForm`, `Ac1_Pack_DictionaryFormOfARowRound_KeepsThePerNameLists`).
**Max execution time**: 1s

### FT-X-60: A C# dict member in a round that cannot hold the rounds is refused at build

**Summary**: A `Dict` member in a `Repeat`/`Times` whose member type cannot hold one dictionary per round used to build and be pack-only (unpack could never fill it); it is refused at construction naming the member, by the same predicate as FT-X-59; valid dict rounds build and pack as before (loop 21, AZ-2389, decision U9).
**Traces to**: AZ-2389 AC-1, AZ-2389 AC-2
**Category**: Errors

**Preconditions**:
- C# (net10.0 and netstandard2.0)

**Input data**: `Repeat(0, Dict(Ids, u8 a))` and `Times(...)`; member types `Dictionary<string,object?>`, `string`, `List<int>`, `int[]` (cannot hold) against the types that can; two rounds holding 10 and 11 under the key `a` (`01 0100 010061 0a 0100 010061 0b` for the narrow form)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build the scheme with each of the four member types | `ArgumentException` naming `'Ids'` and containing `one dictionary per round` |
| 2 | build with a type that can hold the rounds, unpack the two rounds | builds iff typed unpack binds it; unpack gives `[{a:10},{a:11}]` |
| 3 | build the list form (`List<int>`, `List<long>` refused; `List<List<object?>>`, `object[]`, `IList`, `object` build) | the loop 20 review A1 and A2 outcomes hold; unpack gives `[[10],[11]]`; one round gives a list of one list |

**Expected outcome**: steps 1 to 3 as above. Tests: C# `RoundCollectionMemberTests.DictInARound_ThatCannotHoldTheRounds_IsRefusedAtConstructionNamingTheMember` (four rows), `DictInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt`, `ListInARound_BuildsIfAndOnlyIfTypedUnpackBindsIt`, `ListOfScalarsInARound_IsRefusedNamingTheMember`, `ObjectArrayInARound_BindsAsBefore`, `ListInARound_OneRound_BindsAListOfOneList`. No blackbox row (the spec says unit tests only).
**Max execution time**: 1s

### FT-X-61: An empty `times` or `repeat` body is refused when the scheme is built; the F33 request fails in under a second

**Summary**: A `times`/`repeat` body with no member charged 0 slots and wrote 0 bytes, so a list of 65 535 groups each holding `times(65535) {}` took 93 s in TypeScript (security F33, estimated 1.7 h in Python); building such a scheme now fails in all six packages naming the kind and the anchor (loop 21, AZ-2390). A body that holds a zero-width member (`bytes` of width 0, a flag byte, a member-less `flags`) still builds: the budgets bound it.
**Traces to**: AZ-2390 AC-1, AZ-2390 AC-2, AZ-2390 AC-3
**Category**: Errors

**Preconditions**:
- TypeScript, Python, Java, C# and Rust; C++ (`SchemeInvalid` at construction, direct children only)

**Input data**: reference rows 15 to 26:

| Row | Scheme | Outcome |
|-----|--------|---------|
| 15 | `repeat(0, [])` | `repeat 0: the body holds no member; a round of it would charge no slot and write nothing` |
| 16 | `u8 n; times(1,0,[])` | `times 1: the body holds no member; ...` |
| 17, 18 | a body of only `when`s (also nested `when`s) with no member | the same text (a `when` with no member is no member) |
| 19 | `repeat(0, [group(g, [])])` | the existing text first: `empty group g: allowed only directly inside flags or a flag bit; move it into flags` |
| 20 | `list items of group { u32 n; times(n){} }` (the F33 request) | `times 1: the body holds no member; ...` at build, a few ms; no packet is attempted |
| 21 | `u8 n; times(n){ bytes(0) v }`, `maxSlots` 5, `n` 10 | builds; pack `v: the rounds would hold 6 slots, above the limit of 5 slots` |
| 22, 23 | `repeat(0, [flagByte m])`; `repeat(0, [flags(0, [])])`, `{}` | build; pack `01` |
| 24 | `repeat { u8 k }` `{k:[7,8]}`; `u8 n; times(n){ u8 k }` `{n:2, k:[7,8]}` | `010708`; `01020708` (unchanged) |
| 25 | the empty body under `flags`, a flag bit, a `when`, a group, a list item | refused with the same text |
| 26 | `repeat(0, [flags(0, [group(g, [])])])` | builds; packs `010100` |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build rows 15 to 20 and 25 | a construction error naming the kind and the anchor (Rust: a build panic; C#: `ArgumentException`; C++: `SchemeInvalid` naming the container); no pack or unpack is attempted |
| 2 | time the row 20 build | under 1 s in each package |
| 3 | build rows 21 to 24, 26 | build; the bytes above |
| 4 | replay `construct_empty_times_body`, `construct_empty_repeat_body`, `construct_empty_round_body_list_element` | `scheme_error`; the list-element case is skipped in Rust and C++ (neither can spell a `times` in a list element), their plain empty `times` case covers the refusal |

**Expected outcome**: steps 1 to 4 as above. Tests: TypeScript `empty-round-body.test.ts` ("AC-1 repeat with no member names the repeat", "AC-1 times with no member names the times", "AC-1 a body of only a when with no member is empty, and so is one nested in another when", "AC-1 a body of only an empty group is refused (an empty group stands only in flags or a flag bit)", "AC-1 the empty body is refused wherever the round stands: flags, a flag bit, a when, a group, a list item", "AC-2 the F33 request shape (a list of groups holding times(65535) {}) fails at build in under 1 s", "AC-3 a body with one u8 builds and packs as before", and the five "still builds" tests); Python `test_empty_round_body.py::test_ac1_row15_*` to `test_ac1_row19_*`, `test_ac2_row20_the_f33_request_shape_fails_at_build_in_under_a_second`, `test_ac3_row21_*` to `test_ac3_row24_*`, `test_ac1_row25_the_same_empty_body_is_refused_wherever_the_round_stands`; Java `EmptyRoundBodyTest.run` (`bothFormsAreRefused`, `containersWithoutMembersAreEmpty`, `everywhereTheRoundStands`, `theF33RequestFailsAtBuild`, `zeroWidthMembersStillBuild`, `nonEmptyBodiesAreUnchanged`); C# `EmptyRoundBodyTests.Ac1_Repeat_EmptyBody_IsRefusedNamingTheKindAndTheAnchor`, `Ac1_Times_*`, `Ac1_TypedRepeatAndTimes_EmptyBody_AreRefused`, `Ac1_Group_EmptyGroupBody_IsRefusedByTheEmptyGroupRuleFirst`, `Ac1_Validate_BodyOfEmptyWhensAndGroups_HoldsNoMember`, `Ac2_F33RequestShape_FailsAtBuildInUnderOneSecond`, `Ac1_EmptyBody_WhereverTheRoundStands_IsRefusedWithTheSameText`, `Ac3_*` (five tests); Rust `empty_round_body_tests.rs::ac1_row_15_*` to `ac1_row_19_*`, `ac2_row_20_*` (three tests), `row_21_*` to `row_23_*`, `ac3_row_24_*`, `row_25_*`, `row_26_*`; C++ `times_count_zero_host_tests.cpp::az2390_empty_round_body_is_refused_at_construction` (empty `times`, empty `repeat`, a `times` in a `when`, a bound `times`; pack of an empty round fails; one-member body builds), `container_tests.cpp::empty_round_body_is_refused` and `hostile_host_tests.cpp::construct_empty_times_body`, `construct_empty_repeat_body`. Gap (review21 #6, G1, loop 22): the C++ check counts direct children only, so an empty `when` body builds there while the other five refuse it; fixing it costs flash. Unpack of old packets is not affected (no packet holds the shape); the zero-width `bytes` hostile unpack vectors `zero_progress_repeat_*` pass unchanged.
**Max execution time**: 1s

### FT-X-62: A round or a list item no longer copies the enclosing scope (TypeScript)

**Summary**: `sliceRound` and `packItem` copied the whole enclosing scope per round or per scalar item, so `times(65535) { u8 }` cost 1.4 s with 100 top-level fields and 23.9 s with 1 000 (security F34); each now takes a view that reads through to the enclosing scope, so the cost follows the names a round holds; the bytes are unchanged (loop 21, AZ-2391). The README says `maxBytes` is also the memory bound (2 to 3 times the packet).
**Traces to**: AZ-2391 AC-1, AZ-2391 AC-2
**Category**: Timing

**Preconditions**:
- TypeScript; other packages probed only (the batch report records any quadratic path)

**Input data**: 100 and 1 000 top-level `u8` fields, then `times(65535) { u8 }` (65 640 and 66 540 bytes) or a `list` of 65 535 `u8` (65 638 and 66 538 bytes)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the four schemes before and after the change | `times`: 1 436 ms and 23 878 ms before; 22 ms and 21 ms after. `list`: 1 358 ms and 24 621 ms before; 22 ms and 19 ms after |
| 2 | compare the two sizes in one run (best of 3) | the 1 000-field time is at most 2 x the 100-field time + 5 ms |
| 3 | pack a row with the count and fields before the `times` | the bytes are those of a copy |

**Expected outcome**: steps 1 to 3 as above. Tests: TypeScript `round-scope-cost.test.ts` ("AC-1 times(65535) { u8 } with 1000 top-level fields packs within 2x the 100-field time", "AC-1 a list of 65535 u8 items with 1000 top-level fields packs within 2x the 100-field time", "AC-2 the bytes are those of a copy: the count and the fields before the times are written as before") and the 765 loop 20 tests of the suite (AC-2). The ratio test is a timing test: it flaked once under parallel worker load in wave 2 (about 20 ms with 5 ms slack, review21 #5) and passed in the idle total run (880 of 880); judge it on an idle machine.
**Max execution time**: 1s

### FT-X-63: Each refused hostile `pack` and `construct` case names the rule that refuses it, in the four loaders that did not

**Summary**: The Python, Java, Rust and C++ hostile loaders asserted only that pack refused, so a refusal by the wrong rule passed; each now has a table that maps every refused case to a message fragment (C++: an error kind and an order id); the two C++ pins of AZ-2356 check the count-0 rule, not the late rule (loop 21, AZ-2392; TypeScript and C# already had a table, extended to the new cases).
**Traces to**: AZ-2392 AC-1, AZ-2392 AC-2
**Category**: Errors

**Preconditions**:
- The six loaders as built in loop 21; the 55 cases of `fixtures/hostile/cases.txt`

**Input data**: the refused `pack` cases (23 of the 31 `pack` cases) and the 12 `construct` cases; for example `pack_round_slots_over_limit` -> `b: the rounds would hold 4 slots, above the limit of 3 slots`; `pack_flags_short_list` -> `v: 1 items, repeat count 2; ...`; `construct_empty_times_body` -> `times 1: the body holds no member`; C++ `pack_split_count_zero_after_byte_list` -> `BadValue` on id 2

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run the four loaders over all refused cases | each refusal carries the table's rule; a case with no table entry, or a table entry with no case, fails (`assert_tables_cover`, "has a table entry" checks) |
| 2 | change a table entry or the rule that fires (temporary edit, reverted) | the loader fails; shown once per loader at step 11 of the loop (assessment S12) |
| 3 | the C++ AZ-2356 pin | passes through the count-0 rule (`x` sets the bit so the late rule cannot fire first), `BadValue` on id 2 |

**Expected outcome**: steps 1 to 3 as above. Tests: Python `hostile_refusals.py` (`PACK_REFUSAL`, constructs) with `test_hostile_vectors.py::test_every_refused_pack_vector_names_its_rule_and_no_other_does`, `test_pack_vector_gives_the_bytes_or_is_refused_by_its_rule`, `test_every_construct_vector_has_a_scheme_and_a_rule`, `test_construct_vector_is_refused_by_its_rule`; Java `HostileRefusals` (`PACK`, `CONSTRUCT`) read by `HostileVectorTest.replayPack` and `replayConstruct` (`refusedByRule`); Rust `hostile_tests/refusals.rs` (`PACK_REFUSAL`, `CONSTRUCT_REFUSAL`, `assert_tables_cover`) read by `hostile_tests.rs::hostile_vectors_error_without_panic_or_hang`; C++ `hostile_pack_loop21.hpp` (`kRefusals`) read by `hostile_host_tests.cpp` (`refusal_is_named`). No fixture format change was needed. AC-2 (the negative check) is evidence from the loop, not a standing test: nothing in the suites runs a wrong-rule case on purpose. Remaining gap: the Python, Java, Rust and C++ tables pin the message or error kind, not a rule id; a text change in a package needs its table edited.
**Max execution time**: 10s

### FT-X-64: C# count text above `int.MaxValue`, a lone `byte[]` in a `repeat`, and the old `WithLimits` overload

**Summary**: The C# error for a count above `int.MaxValue`, the outcome of a lone `byte[]` for a `Bytes` name in a `repeat`, and a binary-compatible `WithLimits(maxRounds, maxSlots)` overload are pinned (loop 21, AZ-2393; loop 20 review A5, A6, A7).
**Traces to**: AZ-2393 AC-1, AZ-2393 AC-2, AZ-2393 AC-3
**Category**: Errors

**Preconditions**:
- C# (net10.0 and netstandard2.0), dictionary and typed rows

**Input data**: counts from `u32`, `i64` and `u64` fields driving a `sized`, `bits`, `packed` or `times`; a `repeat` of `Bytes` (one byte per round); `new Scheme(...).WithLimits(...)` called with the loop 19 signature by reflection

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack a count above `int.MaxValue` | `Out: count 'U' is 3000000000, which does not fit an int` (`sized`); `OutBits: count 'U' is 2147483648, ...`; `OutKinds: count 'L' is 4294967296, ...`; `times: count 'U' is 3000000000, ...`; `times: count 'L' is -9223372036854775808, ...`; `times: count 'W' is 18446744073709551615, ...` |
| 2 | pack a lone `byte[]` (length 1 or 3) for a `Bytes` name in a `repeat`, dictionary and typed row | `'Raw': a round's value belongs in a list with one entry per round; wrap this value in a list` |
| 3 | the same with a `byte[3]` and `maxRounds` 2 | the limit text comes first: `'Raw': the repeat count is 3, above the limit of 2 rounds` |
| 4 | a `byte[]` `{5, 6}` for a scalar `u8` name in a `repeat` | one round per byte: `010506` |
| 5 | resolve `WithLimits(int, long)` by reflection and call it; call `WithLimits(maxBytes: 77)`, `WithLimits(3)` | the old overload sets `maxRounds` 5, `maxSlots` 9 and keeps `maxBytes` at its default; omitted limits keep their defaults |

**Expected outcome**: steps 1 to 5 as above. Tests: C# `CountTextAndLimitsTests.Ac1_Pack_CountAboveIntMaxValue_ThrowsThePinnedText` (six rows), `Ac2_Pack_LoneByteArrayForABytesNameInARepeat_IsRefusedWithTheWrapText`, `Ac2_Pack_LoneByteArrayInATypedRowRepeat_IsRefusedWithTheWrapText`, `Ac2_Pack_LoneByteArrayLongerThanTheRoundLimit_IsRefusedWithTheLimitText`, `Ac2_Pack_ByteArrayForAScalarNameInARepeat_IsOneRoundPerByte`, `Ac3_WithLimits_LoopNineteenSignature_ResolvesAndSetsTheTwoLimits`, `Ac3_WithLimits_OmittedAndNamedLimits_KeepTheirDefaults`. The README upgrade note is step 13's.
**Max execution time**: 1s

### FT-X-65: The hostile case file holds 55 cases; six loaders replay the 15 new ones with the outcome in the case row

**Summary**: `fixtures/hostile/cases.txt` gains 12 `pack` and 3 `construct` cases from the loop 21 reference so a seventh package inherits each rule; the 40 older cases are unchanged; every loader runs a case or reports it skipped with a reason (loop 21, AZ-2394).
**Traces to**: AZ-2394 AC-1, AZ-2394 AC-2
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 21

**Input data**: the 15 new cases (README sections of `fixtures/hostile/README.md`):

| Case | Stage | Outcome | Not run by |
|------|-------|---------|-----------|
| `pack_round_slots_at_limit` | pack | `0101010203` | C++ |
| `pack_round_slots_over_limit` | pack | `pack_error` | C++ |
| `pack_round_slots_flags_at_limit` | pack | `0103050306` | C++ |
| `pack_round_slots_flags_over_limit` | pack | `pack_error` | C++ |
| `pack_flags_short_list` | pack | `pack_error` | Rust, C++ |
| `pack_flags_short_list_filled` | pack | `010101050200` | none |
| `pack_split_times_absent_body` | pack | `0102025a00` | C++ |
| `pack_late_when_in_bit_body` | pack | `0101010509` | none |
| `pack_count_one_clear_when` | pack | `pack_error` | none |
| `pack_bits_count_clear_when`, `pack_packed_count_clear_when`, `pack_sized_count_clear_when` | pack | `pack_error` | none |
| `construct_empty_times_body`, `construct_empty_repeat_body` | construct | `scheme_error` | none |
| `construct_empty_round_body_list_element` | construct | `scheme_error` | Rust, C++ |

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run `fixtures/hostile/check-cases.sh` and `cases.test.sh` | `hostile cases ok: 55`; the corrupted copies still exit non-zero |
| 2 | each loader replays the 55 cases | the outcome of the table; a skipped case prints its reason; a package never skips silently |
| 3 | the 40 older cases | unchanged (golden `4001000065cd1d00a3e1110100`, route and ring fixtures pass) |

**Expected outcome**: step 1 `hostile cases ok: 55`; steps 2 and 3 as above, replayed in the total run (6 suites green). Loader tests: TypeScript `hostile.test.ts` ("shared pack vectors", "shared construct vectors") with `support/hostile-pack.ts`; Python `test_hostile_vectors.py` with `hostile_loop21_support.py` (`LOOP21_PACK_CASES`, `LOOP21_CONSTRUCT_CASES`); Java `HostileVectorTest` with `HostileLoop21`; C# `HostilePackVectorTests.EveryPackCase_HasACSharpScheme`, `PackCase_ReturnsTheBytesOrRefuses` and `HostileVectorTests.EveryConstructCase_HasACSharpScheme`, `ConstructCase_FailsSchemeConstruction`; Rust `hostile_tests.rs` (`hostile_vectors_error_without_panic_or_hang`) with `hostile_tests/pack_cases.rs` (`PACK_NOT_RUN`); C++ `hostile_pack_loop21.hpp` (`kPackHandlers21`, `kPackSkips21`) with `hostile_host_tests.cpp`. Open: the batch report (row 11) says some older TypeScript hostile schemes (`row4_packed_*`) pass `packed(2, ...)` (width 2) where the fixture README says width 1; the schema was not checked against the README (assessment "Not walked").
**Max execution time**: 10s

## Loop 21 loop-level acceptance criteria mapped to scenarios

`_docs/02_task_plans/parity-rules-and-round-cpu-bound/acceptance_criteria.md` lists AC-L1 to AC-L11. The matrix has no loop-level rows for earlier loops, so these are mapped here and the matrix carries the per-spec rows.

| Loop AC | Scenario | Result |
|---------|----------|--------|
| AC-L1 slot rule, pack at `maxSlots` unpacks | FT-X-53 | met in five packages; C++ has no slots; U16 open (Java nested row) |
| AC-L2 short optional list, count 1 behind a clear `when`, `bits`/`packed`/`sized` counts | FT-X-54, FT-X-57 | met in TypeScript, Python, Java, C#; Rust open (U13); the no-value `bits` row open (U11) |
| AC-L3 split-bit clear bit, C++ late `when` | FT-X-55, FT-X-56 | met |
| AC-L4 arm stack at most 512 B, flash at most 8 192 B | FT-X-56 | 456 B and 8 152 B |
| AC-L5 C# exact types, rounds bound to rows, dict member refused, `WithLimits` | FT-X-58, FT-X-59, FT-X-60, FT-X-64 | met; no ring driver for a row round |
| AC-L6 empty round body refused, F33 under 1 s | FT-X-61 | met; C++ looks through direct children only (G1) |
| AC-L7 flat round cost | FT-X-62 | met |
| AC-L8 rule tables in four loaders | FT-X-63 | met |
| AC-L9 15 new hostile cases in six loaders | FT-X-65 | met |
| AC-L10 accepted rows keep their bytes | FT-X-53 to FT-X-65 | golden, route, ring unchanged; one accepted-row test edit in TypeScript (`{a:[1, undefined], b:[5,6]}`) |
| AC-L11 files at or under 500 lines | review21 | "no file over 500 lines" |
