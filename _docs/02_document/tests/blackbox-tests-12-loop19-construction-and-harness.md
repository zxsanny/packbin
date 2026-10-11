# Blackbox Tests 12: Loop 19 construction checks, probes and harness (FT-X-31 to FT-X-37)

Part of the blackbox set; the index is [blackbox-tests.md](blackbox-tests.md). Continues [blackbox-tests-11-loop19-rounds-and-split-form.md](blackbox-tests-11-loop19-rounds-and-split-form.md). Test names were checked by grep in each package's test directory.

### FT-X-31: A short `times` list in Python is a named error

**Summary**: Python packs a `times` whose list is shorter than the count only as an error naming the member, not as a bare `IndexError`, outside `flags` and under a `when`; members under `flags` keep their short-list rule (loop 19, AZ-2336).
**Traces to**: AZ-2336 AC-1
**Category**: Errors

**Preconditions**:
- Python as built in loop 19

**Input data**: `u8 a; times(count a){ u8 x }` with `a = 3`, `x = [1, 2]`; the same under a `when`; a short list for a member under `flags` and in a split flag bit

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack `a = 3`, `x = [1, 2]` outside `flags` and under a `when` | an error naming `x`; no `IndexError`; no bytes |
| 2 | pack a short or empty list for a bool, scalar, `u2`, nested `flags` or group member under `flags` | the member is absent, as before (the owner kept this rule) |

**Expected outcome**: step 1 is a named error; step 2 is unchanged. Tests: Python `test_times_longer_list.py::test_ac5_a_shorter_list_is_refused_naming_the_member`; `test_times_short_list.py` (`test_ac5_a_plain_member_refuses_a_short_list_naming_the_member`, `test_ac5_a_member_under_when_refuses_a_short_list_naming_the_member`, `test_ac1_*` to `test_ac3_*` for the unchanged `flags` rule); three tests that expected `IndexError` were rewritten. The names are matched by content: no test cites AZ-2336 (the spec's own AC id is AC-1). Not specified: a `repeat` over a `flags` member with an empty list is still a bare `IndexError` (assessment G2, loop 20).
**Max execution time**: 1s

### FT-X-32: A C# group element uses its own members only

**Summary**: When a list or dict element is a group that lacks a member, C# no longer takes the value from the outer row; pack fails naming the missing member, as TypeScript does (loop 19, AZ-2337).
**Traces to**: AZ-2337 AC-1, AZ-2337 AC-2
**Category**: Errors

**Preconditions**:
- C# as built in loop 19

**Input data**: a list and a dict of group elements `u8 a, u8 b`, anchored and unanchored, where the outer row holds a value with the name of the missing element member `A`; a typed element missing a member; complete elements; the `listgroup` and `dictgroup` ring packets

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack an element missing `A` while the outer row holds `A` | `ArgumentException` naming `'A'` (it packed with the outer value before); also for an element member out of range |
| 2 | pack complete elements in dictionary rows and typed rows; run the rings | bytes unchanged |

**Expected outcome**: step 1 throws in the list and dict forms, anchored or not; step 2 is unchanged. Tests: C# `GroupElementMembersOnlyTests` (`Ac1_Pack_ListElementMissingAMemberTheRowHolds_NamesTheMember`, `Ac1_Pack_DictionaryValueMissingAMemberTheRowHolds_NamesTheMember`, `Ac1_Pack_ElementMemberOutOfRange_StillNamesTheMember`, `Ac1_Pack_TypedElementMissingAMember_NamesTheMember`, `Ac2_Pack_CompleteElementsInDictionaryRows_BytesAreUnchanged`, `Ac2_Pack_CompleteTypedElements_BytesAreUnchanged`). Upgrade note: dictionary rows that relied on outer values now error naming `'A'`.
**Max execution time**: 1s

### FT-X-33: An `eq` value the source cannot hold is refused when the scheme is built

**Summary**: A `when` whose `eq` value is outside the integer source's range, not an integer, NaN, or a bool for an integer source fails construction in the six packages; valid values and the range edges build and pack as before (loop 19, AZ-2338; owner decision 11).
**Traces to**: AZ-2338 AC-1, AZ-2338 AC-2, AZ-2338 AC-3, AZ-2338 AC-4
**Category**: Errors

**Preconditions**:
- The six packages as built in loop 19, including the review fixes (Java `u2` slot 0 to 3, TypeScript 64-bit range through BigInt, C# exact whole-number check on the double); C++ refuses out-of-range integers only

**Input data**: hostile `eq_out_of_range`: id0 `u8 a`; `when` `eq(0, 300)` { `u8 v` }; and per package `eq(u8, 300)`, `eq(u8, -1)`, `eq(u16, 70000)`, `eq(i8, 200)`, `eq(u64, -1)`, `eq(u2 slot, 4)` and `eq(u2 slot, 7)`, a flag byte with 256, `"x"`, NaN, 1.5, `true`, `1e30`, `null`; `eq(u8, 5)`, range edges 0, 255, i8 -128, u64 max, u2 3; `255.00000000000003` on a `u8` (C# review A4); `eq(0, 2**64)` on u64 and `eq(0, 2**63)` on i64 (TypeScript review B8)

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | build each refused scheme | a construction error naming the `when` and the member: `ArgumentException` (C#), `RangeError` (TypeScript), `ValueError` (Python), a thrown exception with the message "when 1 tests field 0 against ..., which that field can not hold" (Java), a panic at `MapScheme::new` (Rust), a compile error or `SchemeInvalid` (C++, integers out of range) |
| 2 | build each valid value and pack a row | bytes unchanged |
| 3 | replay `eq_out_of_range` | `scheme_error` in all six; the C++ literal fails to compile (`cpp/tests/compile-fail/when_eq_out_of_range.cpp`) and its vector builds the scheme at run time with 300 |

**Expected outcome**: step 1 is an error in every refused case; step 2 unchanged; step 3 `scheme_error` in six. Changed behavior (upgrade notes): TypeScript no longer accepts `eq(intSource, null/undefined)` (4 + 2 existing tests rewritten, bytes `010007` became `0100`); C# `FloatConditionValueTests` now refuse NaN, infinity, 1e30 and 1.5 at construction. Tests: C# `EqValueConstructionTests` (`Construct_EqValueTheSourceCannotHold_IsRefusedNamingTheWhenAndTheMember`, `Construct_EqValueInTheSourceRange_Builds`, `Construct_EqValueOutOfRangeInAListElement_IsRefused`, `Pack_EqValueInRange_BytesAreUnchanged`); TypeScript `eq-value-checked.test.ts`; Python `test_eq_value_checked.py` (`test_ac1_*` to `test_ac4_*`); Java `EqValueCheckedTest` (`ac1OutOfRange`, `ac2NotAnInteger`, `ac3BoolForInteger`, `ac4ValidValueBuilds`) and `ReferenceScopeTest` ("loop 19 B3" cases); Rust `eq_range_tests.rs` (`ac1_*`, `ac2_*`, `ac4_*`); C++ `eq_value_checked_host_tests.cpp` (`ac1_a_value_outside_the_source_range_is_refused`, `ac1_a_u2_slot_holds_0_to_3`, `ac1_a_refused_scheme_writes_nothing`, `ac4_a_valid_value_builds_and_packs_as_before`) and the compile-fail case. Not specified (assessment U5 to U7): whole-number floats (`5.0`) are accepted in C# and TypeScript and refused in Java, Python and Rust; C++ `eq(u8, true)` and `eq(u8, 1.5)` still build; `u64` numbers above 2^53 stay accepted in TypeScript.
**Max execution time**: 1s

### FT-X-34: The fraction-slot probe table

**Summary**: What each package does with a fraction in a `u2` slot, a `bits` item and a `packed` item is recorded in a per-package table; it is evidence, not a behavior change (loop 19, AZ-2339).
**Traces to**: AZ-2339 AC-1
**Category**: Errors

**Preconditions**:
- The packages as built in loop 19; the rows of AZ-2309 (FT-X-20)

**Input data**: 0.5, 1.5, 2.5 and 2.999 as `double`, `float`, `Decimal` or `BigDecimal` where the language has them; whole floats 1.0 and 3.0; valid integers; a `BigDecimal` 1E+400

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | each package packs the rows | bytes or an error per package and row, in `batch_01_loop19_report.md` |

**Expected outcome**: C#, TypeScript and Python refuse every fraction (Python also `Decimal`); Rust refuses every float and takes integers only; C++ has no way to write a fraction (`static_assert` or `SchemeInvalid`); Java refuses `Double` fractions but packs a `BigDecimal` fraction truncated (`1.5` in `u2` gives `0101`) and `1E+400` as `0100`, which is assessment G1 for loop 20. Whole floats: accepted in C# and TypeScript, refused in Java and Python; Python accepts `IntEnum` members, C# refuses enums (assessment U5, U6). There is no executable test for this scenario: the evidence is the table (AZ-2339 AC-1 is a report, probe only).
**Max execution time**: not applicable

### FT-X-35: A lone flag member in a C++ group is present

**Summary**: `flags(group(flag_byte(0), flag_bit(0, x)))` with only `x` set packs `01010105` in C++: the group counts as present because its only member holds a value (loop 19, AZ-2340).
**Traces to**: AZ-2340 AC-1
**Category**: Bytes

**Preconditions**:
- The C++ core as built in loop 19 (continues FT-X-15, FT-X-13)

**Input data**: the scheme above with `x = 5`

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | pack the row and unpack it | `01010105` (the flags byte `01`, the group's own flag byte `01`, then `05`); the row round-trips |
| 2 | pack the row with no value | `0100`: the flags byte is clear |

**Expected outcome**: the hex above. Test: C++ `flags_when_member_host_tests.cpp::lone_flag_bit_member_in_a_group_is_present` (also checks `0100` for the empty row). This pins the result that FT-X-15 listed as open (batch 1 discoveries 3 and 4 of loop 18): the group is present through its one value.
**Max execution time**: 1s

### FT-X-36: `run-suite.sh python` fails clearly on a broken venv

**Summary**: The suite runner checks that the Python venv can import pytest; if it cannot, it exits non-zero with a message naming the venv and the rebuild command; it does not clear a directory that is not a venv; a missing venv is built with the pinned pytest (loop 19, AZ-2341).
**Traces to**: AZ-2341 AC-1
**Category**: Errors

**Preconditions**:
- `.github/workflows/run-suite.test.sh`, registered in the `scaffold` job of `test.yml`; all interpreters are fakes that log their arguments, so there is no network and no real pytest

**Input data**: a venv whose interpreter cannot `import pytest`; a usable venv; a failing pytest; a directory that is not a venv holding a file `precious.txt`; a missing venv path

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | run the script on a venv that cannot import pytest | non-zero exit and a message naming the venv path and the rebuild command (`rm -rf <venv>`) |
| 2 | run it on a usable venv | `python -m pytest` is called with the tests path; its success is the exit code |
| 3 | run it with a failing pytest | non-zero exit |
| 4 | run it on a directory that is not a venv | the directory is not cleared; `precious.txt` stays |
| 5 | run it on a missing venv | the venv is built with the pinned pytest and then used |

**Expected outcome**: `run-suite.test.sh: all checks passed`; removing the `-m pytest` line fails two checks (mutation check of the review fix pass C4). On the dev host the real broken venv `/tmp/packbin-pytest` (no `python` on PATH, only `python3`) is now reported by name. Not covered: a real pytest run (the fakes stand in; the six package suites cover pytest itself).
**Max execution time**: 5s

### FT-X-37: Split files keep their behavior

**Summary**: Rust `walk/unpack.rs` and `field/mod.rs`, Java `Walker.java` and C# `Packbin.cs` and `Walker.cs` were split by responsibility; each stays under 400 lines and every suite gives the same counts as before (loop 19, AZ-2342).
**Traces to**: AZ-2342 AC-1, AZ-2342 AC-2
**Category**: Bytes

**Preconditions**:
- Code moved only; public API unchanged

**Input data**: line counts before and after; the C#, Rust and Java suites; the golden and route fixtures

**Steps**:

| Step | Consumer Action | Expected System Response |
|------|----------------|------------------------|
| 1 | count lines | C# `Packbin.cs` 417 to 210 (new `SchemeOrder.cs` 258), `Walker.cs` 418 to 299 (new `Walker.Flags.cs` 136, `Walker.Equality.cs` 34); Rust `walk/unpack.rs` 471 to 352 (new `walk/cursor.rs` 121), `field/mod.rs` 479 to 332 (new `field/leaf.rs` 157); Java `Walker.java` 464 to 387 (new `Presence.java` 138) |
| 2 | run the three suites | C# 844 of 844 on net10.0 and netstandard2.0; Rust 479 before and after; Java output identical |

**Expected outcome**: no touched file above 400 lines; suites unchanged; golden `4001000065cd1d00a3e1110100` unchanged. Not covered by this task: `csharp/tests/LayoutTests.cs` (517 lines) and `rust/src/scheme/bound.rs` (514 lines) are older than the loop and stay over the 500-line soft cap (assessment G5, loop 20).
**Max execution time**: not applicable (the suites run in the total run)
