# Feature assessment — loop 12

loop: 12
feature: bool-flag-limit (epic AZ-2069: AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089)
rounds: 2
verdict: EXTEND
report_of_round: 2

## Round 1

**Date**: 2026-10-05
**Implement pass**: batch 01 (AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089), implementation report `_docs/03_implementation/implementation_report_bool_flag_limit_loop12.md`, batch report `_docs/03_implementation/batch_01_loop12_report.md`, commit f4c92f0 (diff `7a5a235..f4c92f0` read for `python/`, `typescript/`, `csharp/`, `java/`, `rust/`, drivers, `language-pair.sh`, README)
**Verdict**: CLARIFY — 19 covered / 11 out-of-scope / 6 gap-clear / 4 gap-unclear

**Intent baseline.** The five specs in `_docs/02_tasks/done/` (AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089), the user decisions in `_docs/04_refactoring/02-whole-project-assessment/analysis/bugfix_task_plan.md` § User decisions, the placement rule in `_docs/loops/loop12/plan12.md:11` (C++ `cpp/include/packbin/order.hpp` `check_shape`: a bool or empty group only as a direct child of `flags` or a flag-byte bit), `fixtures/hostile/cases.txt`, and the `boolflag` / `booltrue` rings in `.github/workflows/language-pair.sh`. `scenarios.md absent (pre-4.7 spec)`, so no rows were appended. There is no loop-level `problem.md`. Where a gap needs a quoted basis, the project-level `_docs/00_problem/problem.md` / `acceptance_criteria.md`, `_docs/01_solution/schema.md`, `README.md` and the specs are used.

**Owner decisions applied (not re-asked).**
- C# throws when a flag group's bit is set and one of its values is missing.
- Java decides flag bits per round, keeps one list entry per round (aligned), clears `seen` each round, lets count and `when` targets be only integer or bool fields, and refuses a `repeat` or `times` nested inside a round.
- Follow-up tickets: AZ-2126 (`eq` on a bool accepts only `true`; it also holds the bool-as-count question), AZ-2127 (Java nested rounds) and AZ-2128 (flag group presence in C#, Java, Rust).
- Error kind and label stay with C15.

**Method note.** Besides reading the code, the analyst ran scratch probes outside the repo (Python via `PYTHONPATH=python/src`; `node --experimental-strip-types` on `typescript/src/index.ts`; a .NET console project compiling `csharp/*.cs`; `javac` of `java/src/main/java`; a copy of the Rust crate; a C++ host build of `cpp/src/core/*`), plus the same probes against `git archive 7a5a235` for TypeScript, Java and Rust. Scratch suite reruns: Rust 121 passed; Python 93 passed, 1 failed only because `README.md` was not copied; TypeScript 100 passed, 3 todo, 1 failed only because `tsc` was not installed in the copy. C# and Java suites were taken from the batch report (C# 194, Java 0 failures). No repository file was touched.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A bool sets its flag bit only for `true`; `false` and a missing value leave it clear; unpack gives `true` only for a set bit (C#, TS, Rust, Python, Java) | covered | AZ-2079 AC-1/AC-2, AZ-2080 AC-1/AC-2, AZ-2082 AC-5, AZ-2083 AC-1, AZ-2089 AC-8. Tests: `csharp/tests/BoolFlagRuleTests.cs::Ac1_BoolFalse_ClearsTheBitAndRoundTripsFalse`, `::Ac2_BoolTrue_SetsTheBitAndNullClearsIt`; `typescript/tests/bool-flag.test.ts` "bool false leaves the flag bit clear", "bool unpacks true only when set"; `rust/src/flag_bits_tests.rs::ac5_typed_bool_in_flags_sets_the_bit_only_for_true`, `::ac5_map_bool_zero_under_flags_leaves_the_bit_clear`; `python/tests/test_bool_placement.py::test_bool_in_flags_true_false_absent`, `::test_bool_false_in_flags_unpacks_without_true`; `java/.../BoolPlacementTest.java::combinedFormBitRuleUnchanged`. Code: `csharp/Walker.Presence.cs:8-18`; `typescript/src/fields.ts:290-297`, `walker.ts:89-92`; `rust/src/walk/pack.rs:93-160`, `scheme/bound.rs:338-357`; `python/src/packbin/_pack.py:46-47`; `java/.../Walker.java:22-24` | spec ACs |
| S2 | A bool or an empty group anywhere except as a direct child of `flags` or a flag-byte bit fails construction: top level, plain group, group under flags, `when`, `repeat`, `times`, list element, dict element, nested row | covered | AZ-2079 AC-4/AC-5, AZ-2080 AC-5/AC-6, AZ-2082 AC-4, AZ-2083 AC-2/AC-3, AZ-2089 AC-5/AC-6. Tests: `BoolFlagRuleTests.cs::Ac4_BoolNotDirectlyUnderFlags_FailsConstruction` (10 shapes), `::Ac5_EmptyGroupNotDirectlyUnderFlags_FailsConstruction`; `bool-flag.test.ts` "bool outside flags is a scheme error" (8 shapes), "empty group outside flags is a scheme error"; `flag_bits_tests.rs::ac4_*` (8); `test_bool_placement.py::test_bool_top_level_is_scheme_error`, `::test_bool_in_group_when_repeat_times_element_is_scheme_error` (7); `BoolPlacementTest.java::boolOutsideFlagsIsRejected`, `::emptyGroupOutsideFlagsIsRejected`. Code: `csharp/Packbin.cs:195-201,212-213,253-254`; `typescript/src/flag-scope.ts:43-75`, `index.ts:78`; `rust/src/field/shape.rs:80-91`; `python/src/packbin/_nodes.py:402-430`; `java/.../SchemeOrder.java:102-106,126-131`. Probe: all 8 shapes refused in all five. Python empty group excluded (O9) | spec ACs + assess-round-1 |
| S3 | A ninth bit fails construction in short and split form in every package; eight bits still build and keep bit 7 | covered | AZ-2079 AC-6, AZ-2080 AC-7, AZ-2082 AC-3, AZ-2083 AC-4 (Java already enforced: AZ-2089 Excluded). Tests: `BoolFlagRuleTests.cs::Ac6_*`; `bool-flag.test.ts` "ninth flag bit is a scheme error" (eight-bit round trip `01810107`); `flag_bits_tests.rs::ac3_*`; `test_bool_placement.py::test_ninth_flags_child_is_scheme_error`, `::test_eight_flags_children_pack`. Code: `csharp/FlagGroup.cs:12-19`; `typescript/src/fields.ts:126-150`; `rust/src/field/shape.rs:40-56,92-101`; `python/src/packbin/_nodes.py:101-106,318-321`; `java/.../Field.java:329`; C++ `order.hpp:149-153` | spec ACs |
| S4 | A split-form bool (`m.bit(bool)`) packs `0101` / `0100` and unpacks `true` for a set bit | covered | AZ-2079 AC-1 (split row), AZ-2080 AC-3, AZ-2082 AC-5, AZ-2089 AC-7. Tests: `BoolFlagRuleTests.cs::Ac1_SplitFormBoolFalse_ClearsTheBit`; `bool-flag.test.ts` "split form bool false"; `flag_bits_tests.rs::ac5_flag_byte_bool_round_trips_when_set`, `::ac5_flag_byte_bool_absent_when_clear`; `BoolPlacementTest.java::splitFormBoolUnpacksTrue`. Code: `typescript/src/walker.ts:101-105`; `rust/src/walk/unpack.rs:190-198`; `java/.../Walker.java:221-226`. Python not constructible yet (O6) | spec ACs |
| S5 | C#: a flag group's bit is set when any value-bearing child is present, whatever its kind (`U2`, `Bits`, `Sized`, `Packed`, nested group) | covered | AZ-2079 AC-7. Tests: `BoolFlagRuleTests.cs::Ac7_*`; `FlagGroupValueTests.cs::NestedGroupChild_WithAValue_SetsTheBitAndWritesIt`, `::NestedRowChild_WithAValue_SetsTheBitAndWritesIt`. Code: `csharp/Walker.Presence.cs:20-42` | spec AC |
| S6 | Rust: bit positions come from field order for each flag-byte read; one handle in two schemes packs the same bytes; split-form golden and motion example unchanged | covered | AZ-2082 AC-1/AC-2. Tests: `flag_bits_tests.rs::ac1_*`, `::flag_bits_inside_times_number_from_zero_in_their_own_scope`; `flag_presence_tests.rs::motion_example_bits_follow_field_order`. Code: `rust/src/field/shape.rs:23-71`, `field/map_scheme.rs:44-57`. Probe: handle reuse `010105` / `010105` (before: `010105` / `010205`) | spec ACs |
| S7 | Java: `when` / count references to a later field, or to an outer field from inside `repeat`/`times`, are refused; valid references round-trip; repeat round count from value fields under `flags`/`when`/groups | covered | AZ-2089 AC-1..AC-4. Tests: `ReferenceScopeTest.java::*`; `HostileVectorTest.java` construct cases. Code: `java/.../SchemeOrder.java:62-171`, `Rounds.java:16-43` | spec ACs |
| S8 | Valid schemes keep their bytes: golden, route fixture, language-pair rings | covered | AZ-2079 AC-8, AZ-2080 AC-8, AZ-2082 AC-2, AZ-2083 AC-5, AZ-2089 AC-4. Tests: route and golden tests in every package; `language-pair.sh` rings (batch: all pass). Probe at HEAD vs 7a5a235 (TS, 12 rows): only rows with a `false` bool or empty-group mark changed. Rust's other byte changes are the intended AZ-2082 changes in `README.md:976` | spec ACs + assess-round-1 |
| S9 | Hostile construct vectors fail at construction in each package; `zero_progress_repeat_bool` is now `scheme_error` | covered | Vectors `nine_flag_bits`, `nine_flag_bits_split`, `bool_outside_flags`, `empty_group_outside_flags`. Tests: `HostileVectorTests.cs::ConstructCase_FailsSchemeConstruction`; `hostile.test.ts` construct vectors; `rust/src/hostile_tests.rs`; `test_bool_placement.py::test_construct_vector_is_scheme_error`, `test_hostile_vectors.py::test_vector_is_rejected`; `HostileVectorTest.java`. Exceptions: Python empty group (O9), reference vectors (O11) | spec Blackbox |
| S10 | All six packages agree: `flags(0,[bool on])` false/true/absent → `0100`/`0101`/`0100`; `flags(0,[bool on, u8 n])` `{on:false,n:7}`/`{on:true,n:7}`/`{n:7}` → `010207`/`010307`/`010207`; unpack agrees | covered | Project AC-3; Blackbox "bool false in flags". Test: `language-pair.sh` `boolflag` / `booltrue` rings. Code: the six drivers. Probe: all six give the bytes above. The bool+value row is pinned by tests only in Rust and C++ (Harness gaps) | assess-round-1 |
| S11 | Rust typed and map APIs agree: typed `Some(true)` set, `Some(false)`/`None` clear; map `U8(1)` set, `U8(0)` clear, other → `PackError::Type` | covered | AZ-2082 AC-5, Constraints. Tests: `flag_bits_tests.rs::ac5_*`, `flag_presence_tests.rs::map_bool_other_than_0_or_1_is_a_type_error`. Code: `rust/src/scheme/bound.rs:338-357`, `walk/pack.rs:93-100` | assess-round-1 |
| S12 | Owner decision: C# pack throws when a set flag group misses a value, including inside a nested group | covered | Batch report C# F1. Tests: `FlagGroupValueTests.cs::MixedGroup_*`, `::NullableGroup_*`, `::NestedGroupChild_OuterMemberSetAndValueNull_ThrowsNamingV`. Code: `csharp/Walker.Presence.cs:44-68`, `Walker.cs:126,137-139` | owner decision |
| S13 | Owner decision: Java rounds (round-value flag bits, aligned lists, per-round `seen`, integer/bool targets, nested rounds refused, linear padding) | covered | Batch report Java F1, Mediums, round 3. Tests: `RepeatRoundTest.java::*`; `ReferenceScopeTest.java::referenceNamesIntegerOrBoolOnly`; `FlagStateTest.java::repeatRoundKeepsItsOwnFlagByte`. Code: `java/.../Rounds.java:16-143`, `SchemeOrder.java:146-150,173-179` | owner decision |
| S14 | Owner decision: Rust binds flag bits per flag-byte read; a byte read inside a `when` is not seen after it; split bits under a top-level group or a flags member are set | covered | Batch report Rust F1–F5. Tests: `flag_presence_tests.rs::*`. Code: `rust/src/field/shape.rs:58-71,103-116`, `walk/pack.rs:103-125` | owner decision |
| S15 | Flagged concern "inside flags = direct field of a flag bit": a bool inside a group under flags is refused | covered | AZ-2079 FC, AZ-2080 FC1, AZ-2083 FC2, settled by `plan12.md:11`. Tests as S2 (group-under-flags shapes) | spec flagged concerns |
| S16 | Flagged concern: the empty-group mark follows the true-only rule | covered | AZ-2080 FC2; AZ-2079 AC-3; AZ-2080 AC-4. Tests: TS "empty group mark false"; C# `Ac3_EmptyGroupMark_FollowsTheBoolRule`; Rust `ac5_map_bool_zero_under_a_flag_bit_leaves_the_bit_clear` | spec flagged concern |
| S17 | The wire change for `false` (`0101` → `0100` in C#, TS, Rust) is recorded for upgraders | covered | AZ-2079 NFR; AZ-2080 FC3. Test: `boolflag` ring. Doc: `README.md:976` | spec NFR |
| S18 | Java: a `repeat` inside a list/dict element in a round still builds and round-trips | covered | Owner decision round 3. Test: `RepeatRoundTest.java::nestedRoundsInsideElementsStillBuild`. Code: `SchemeOrder.java:116` | batch discovery #13 |
| S19 | Java: zero-width `times` guard still tested with always-empty bodies | covered | AZ-2074 AC-1. Tests: `HostileUnpackTest.java` AC-1, `ZeroWidthElementTest.java::partlyZeroWidthElementIsError`. Code: `Rounds.java:61-76` | batch discovery #14 |
| O1 | `when(eq(boolId, false))` never matches on unpack; C# and TS still write the body | out-of-scope | AZ-2126 AC-1; owner decision 2026-10-05 | batch discovery #1 |
| O2 | A count naming a bool builds in Java and C++; Java pack/unpack fail, TS refuses at pack, Python packs and round-trips when the bool is true | out-of-scope | AZ-2126 Flagged concern (bool count). Probe `flags(0,[bool on]), sized(1,p,0)` `{on:true,p:61}`: Java `IllegalStateException`, TS `RangeError`, Python `010161` | batch discoveries #9, #15 |
| O3 | C#: a continuing group whose own `bool? Mark = false` turns its bit on, then pack throws for the first missing child | out-of-scope | AZ-2080 Excluded ("Non-empty groups under flags. Their presence stays 'any member present'"); AZ-2082 Excluded; fail-loudly decision (S12) | batch discovery #4 |
| O4 | C#: a `When` inside a flags group is not checked by the group-value rule; a `When` directly under `Flags` is dropped on pack | out-of-scope | AZ-2128 (C# `When`); AZ-2120 | batch discovery #5 |
| O5 | Rust map `times`: values under `when`/`flags`/`group` in a round are dropped | out-of-scope | AZ-2086 Included (map `times` per-round alignment), AC-4. AZ-2086 names flags and `when`, not an anchored `group`: add it when refined | batch discovery #7 |
| O6 | Python split form: `_FlagBit` → `_Bool` unpack is `pass`; a flag byte without its bits drops the bool | out-of-scope | AZ-2100 AC-2 and Flagged concern; AZ-2083 Included ("round trip is tested in task 31") | batch discovery #11 |
| O7 | Java: a `repeat`/`times` nested inside a round is refused for now | out-of-scope | AZ-2127 | implementation report |
| O8 | C#, Java, Rust: a flags group whose only present values are in ignored child kinds drops them | out-of-scope | AZ-2128. TS and Python not covered: see G6 | batch report |
| O9 | Python builds an empty `group(anchor)` outside flags; `empty_group_outside_flags` not met there | out-of-scope | AZ-2083 Excluded; `README.md:972`. Whether to refuse anyway: U3 | AZ-2083 flagged concern |
| O10 | Rust typed API has no flag-byte form | out-of-scope | AZ-2082 Excluded (C18 parity) | AZ-2082 flagged concern |
| O11 | Reference construct vectors still build in TS (3 `it.todo`), C# and Python | out-of-scope | AZ-2090, AZ-2087, AZ-2113 | implementation report |
| G1 | C++ binds a split bit to a flag byte read inside an earlier `when`, packing bytes it cannot read; a byte only inside a `when` still builds in C++ | gap-clear | `schema.md:167`: "A flag byte read inside a `when`, or outside the container that holds the bit, is not visible to that bit, and building the scheme fails naming the bit."; AZ-2100 Flagged concern (loop 11 U2: "a scheme construction error in every package"). Probe (C++): `{k:0, b:6}` → `01000006`, own unpack `TrailingBytes`. Code `cpp/include/packbin/order.hpp:111-124` | batch discovery #8 |
| G2 | Java: a nested-row group inside a `repeat` round fails pack and throws out of `BinaryPacker.unpack` | gap-clear | AZ-2074: "Every Java unpack of a crafted packet returns an error value: no infinite loop, no exception."; `README.md:976`. Probe: `repeat(0, group(get g, set g, u8(0, v)))` unpack `010102` throws `IllegalArgumentException: expected map` (same at 7a5a235). AZ-2101 Excluded points back to AZ-2089; AZ-2127 owns only nested repeat/times | batch discovery #10 |
| G3 | A non-`true` value (`1`, `"yes"`) leaves the bit clear in TS, C#, Python, Java; no test pins it | gap-clear | User decision "set only for `true`"; `README.md:976`. Probe: `on: 1` → `0100` in Python, TS, C#, Java | batch discovery #12 |
| G4 | Split-form bit numbering still follows `.bit()` call order on a shared handle in TS, C#, Java; Rust (this loop) and C++ number by field order per read | gap-clear | C05 "bit positions from field order"; AZ-2082 Outcome; AZ-2100 Included; `README.md:976`. Probes: one handle two schemes → TS `010105`/`010205`, C#/Java `010305`/`010305`, Rust `010105`/`010105`; late-then-early → TS/C#/Java `010109`, Rust `010209`; two reads → TS/C#/Java `01020209`, Rust `01000109` | assess-round-1 |
| G5 | C#: values under `flags` in a `repeat`/`times` round are dropped on pack with no error | gap-clear | `problem.md` "`pack` turns a value into the exact bytes."; AZ-2089 Defect 7. Probe: `Repeat(0, Flags(0, Bool On, U8 N))` On=[T,F,T], N=[1,2,3] → `01` (TS/Java `01030102020303`). Code `csharp/Walker.cs:150-200`, `Walker.Counted.cs:241-250` | assess-round-1 |
| G6 | TS and Python: a flags group whose only values are `u2` (TS also `bits`/`sized`/`packed`) never sets its bit | gap-clear | AZ-2080 Excluded ("any member present"); AZ-2128 Outcome. Probe: TS u2-only `{p:1,q:2}` → `0100`; Python u2-only → `0100`. Code `typescript/src/kinds.ts:13-44`, `python/src/packbin/_pack.py:57-66` | AZ-2128 flagged concern + assess-round-1 |
| U1 | TypeScript `new Scheme(...)` is public and skips every `scheme()` check, including the bool rule | gap-unclear | Probe: `new Scheme(1, [bool(0, on)])` builds, packs `01`, unpacks `{on:true}` | batch discovery #2 |
| U2 | A bool (or any optional value) under `flags` in a `repeat`/`times` round: what unpack returns for a round whose bit is clear | gap-unclear | Java/C++/Rust `repeat` align per round; TS/C#/Python compact; TS repack moves a `true` to another round | batch discovery #3 + assess-round-1 |
| U3 | Empty groups that build inside flags but can never set their bit (Java/Python `group(anchor)` with no fields, C# zero-child nested-row group) | gap-unclear | Probe (C#): `Flags(0, Group((Q x) => x.Nested))`, `Nested = new In()` → `0100`, unpack `0101` → `Nested` null | batch discovery #6, AZ-2083 FC1, AZ-2089 FC2 |
| U4 | A split bit inside a `when` that is not taken still sets its bit in the outer flag byte | gap-unclear | Probe: `010001` in TS, C#, Java, Rust, C++ | batch discovery #16 |

#### Probes at HEAD (scratch copies; "—" = not expressible or not probed)

| # | probe | Python | TypeScript | C# | Java | Rust | C++ |
|---|-------|--------|------------|----|------|------|-----|
| 1 | `flags(0,[bool on])` false / true / absent | `0100`/`0101`/`0100` | same | same | same | typed same | same |
| 2 | unpack `0100` / `0101` | `{}` / `on: True` | no `on` / `on: true` | `{}` / `On: true` | `{}` / `on=true` | `None` / `Some(true)` | ring |
| 3 | `flags(0,[bool on, u8 n])` false,7 / true,7 / n=7 | `010207`/`010307`/`010207` | same | same | same | same | same |
| 4 | `on: 1` | `0100` | `0100` | `0100` | `0100` | map `U8(2)` → `Type` | typed only |
| 5 | 9 members in `flags` | `ValueError` | `RangeError` | `ArgumentException` | IAE | panic | compile-fail |
| 6 | 9th `.bit()` | `ValueError` | `RangeError` | `ArgumentException` | IAE | panic | `SchemeInvalid` |
| 7 | bool at top / group / group under flags / when / repeat / times / list / dict | refused | refused | refused | refused | refused | refused |
| 8 | empty group outside flags | builds (O9) | refused | refused | refused | refused | refused |
| 9 | split bool true / false; unpack `0101` | not buildable | `0101`/`0100`; true | same | same | same | test |
| 10 | `repeat(flags(bool on, u8 n))` on=[T,F,T], n=[1,2,3] | `AttributeError` (AZ-2100) | `01030102020303` | `01` | `01030102020303` | `01030102020303` | — |
| 11 | unpack `01030102020303`: `on` | `[True, True]` | `[true, true]` | `[true, true]` | `[true, null, true]` | per-round maps | — |
| 12 | same body in `times`, c=3 | bool lost (AZ-2100) | `0103030102020303` | `0103000000` | `0103030102020303` | `0103000000` (AZ-2086) | — |
| 13 | one handle, two schemes `[m, m.bit(u8 x)]`, x=5 | — | `010105`/`010205` | `010305`/`010305` | `010305`/`010305` | `010105`/`010105` | — |
| 14 | `[m, early a, late b]`, b=9 | — | `010109` | `010109` | `010109` | `010209` | field order |
| 15 | `[m, m.bit(a), m, m.bit(b)]`, b=9 | — | `01020209` | `01020209` | `01020209` | `01000109` | per read |
| 16 | `[u8 k, m, when(k==1,[m.bit(u8 v)])]`, k=0, v=5 | — | `010001` | `010001` | `010001` | `010001` | `010001` |
| 17 | u2-only group under flags `{p:1,q:2}` | `0100` | `0100` | `010109` | `0100` | `0100` | — |
| 18 | TS repack of row #11 | — | `01030103020203` (≠ input) | — | — | — | — |

### Gaps that need a decision (gap-unclear)

**U1 — TypeScript `new Scheme(...)` skips the checks.** `new Scheme(1, fields)` skips field ids, flag-bit scope and the bool placement rule; `new Scheme(1, [bool(0, on)])` builds and unpacks `on: true` every time. Options: **A** the constructor runs the same checks (no signature change); **B** make the constructor non-public (compile break for `new` callers); **C** leave it and document `scheme()` as the only entry. Recommendation: A.

**U2 — A per-round bool in `repeat` / `times`.** Java, C++ and Rust `repeat` keep one entry per round; TS, C# and Python append only set rounds, so `[true, false, true]` comes back `[true, true]` and the TS repack moves a `true` to another round. AZ-2100 Excluded says Python keeps compact lists. Options: **A** aligned everywhere (row shape changes in TS, C#, Python; reverses the AZ-2100 Excluded line); **B** compact everywhere and refuse optional values inside rounds (undoes the Java decision); **C** leave and document. Recommendation: A.

**U3 — Empty groups that can never set their bit.** Java/Python `group(anchor)` with no fields and a C# zero-child nested-row group build inside flags, but their bit is always clear. Options: **A** refuse them at construction wherever they stand (Java `emptyGroupAsFlagBitStillBuilds` flips; Python then meets `empty_group_outside_flags`); **B** give them a presence member (public API additions); **C** leave and document "always clear". Recommendation: A.

**U4 — A split bit inside a `when` that is not taken.** The bit is set from the row value even when the `when` is not taken (`010001` in five packages); every package still reads the packet. Options: **A** leave it, reword project AC-4 to "when its field is walked" and pin the bytes in a shared vector; **B** clear the bit in all six packages (wire change). Recommendation: A.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| G1 | Given the C++ scheme `u8 k`, `flag_byte(0)`, `when(1, eq(0,1), flag_byte(0), flag_bit(0, u8 a))`, `flag_bit(0, u8 b)`; When `{k:0, b:6}` and `{k:1, a:5, b:6}` are packed and unpacked; Then `01000106` and `010101010506` and both unpack; and with no outer `flag_byte(0)` building fails naming `b` | `schema.md:167`; loop 11 U2 decision | new C++ task (`find_flag_byte` must not look into a `when` that does not hold the bit) |
| G2 | Given `repeat(0, group(get g, set g, u8(0, v)))`; When `{g:[{v:1},{v:2}]}` is packed and `010102` unpacked; Then `010102`, `g == [{v:1},{v:2}]`, and unpack returns an error value (never throws) for any packet | AZ-2074; `README.md:976` | AZ-2127, or AZ-2101 after correcting its Excluded line |
| G3 | Given `flags(0,[bool on])`; When `{on: 1}` is packed in TS, Python, Java (map) and C# (dictionary); Then `0100` and unpack has no `on` | user decision; `README.md:976` | AZ-2126 (test-only) |
| G4 | One handle, two schemes `[m, m.bit(u8 x)]`, x=5 → both `010105`; `[m, early, late]` with `{b:9}` → `010209`; `[m, m.bit(a), m, m.bit(b)]` with `{b:9}` → `01000109`; in TS, C#, Java; a handle shared by two 5-bit schemes builds both | C05; AZ-2082 Outcome; AZ-2100 Included | new task per package (TS, C#, Java) or one cross-package task; Python in AZ-2100 |
| G5 | Given C# `Repeat(0, Flags(0, Bool On, U8 N))`, `Times(1, 0, Flags(1, Bool On, U8 N))`, `Repeat(0, U8 X, Flags(1, U8 N))`; When On=[T,F,T], N=[1,2,3]; A=3; X=[1,2], N=[5,null]; Then `01030102020303`, `0103030102020303`, `010101050200` (as TS and Java) | `problem.md`; AZ-2089 Defect 7 | AZ-2088 or a new C# task |
| G6 | Given TS `flags(0,[group(x=>x.g,[u2(0,p,1,q)])])` and Python `flags(0, group(0, u2((0,p),(1,q))))`; When `{p:1,q:2}`; Then `010109`; and TS bits-only / sized-only groups give `010801ff` / `01010161` | AZ-2080 Excluded; AZ-2128 Outcome | extend AZ-2128 to TypeScript and Python |

### Not walked

- TS `times` / `repeat` with a `when` or anchored `group` child throws "expected number" on pack (AZ-2090 flagged concern; not bool-specific).
- Flag-byte value as a row member (TS: AZ-2091; Rust map internal only).
- `flags` nested as a `flags` member (Python builds it); legality across packages not walked.
- Concurrency: new checks run once at construction; the only shared state is the C#/Java/TS flag-byte handle's bit list (part of G4).
- AC-10 throughput: only Java rounds (`paddingIsLinear` tested) and the Rust `bool_on` check changed; Run Tests covers AC-10.
- C# plain (non-nullable) `bool`: a clear bit unpacks as `false` (the default); consistent with "not true".
- Error kind and label differences: C15.

### Harness gaps

- `scenarios.md` absent (pre-4.7 spec); no loop-level `problem.md`.
- No `batch_01_loop12_review.md`: review findings and in-loop owner decisions (S12–S14, S18) live only in the batch report and have no numbered AC.
- Discovery routing that does not hold: #3 → AZ-2091 (covers only the member leak), #8 "Raise for C++" (no ticket), #10 → AZ-2101 (its Excluded points back to AZ-2089).
- AZ-2126 Flagged concern says TS and Python "refuse at pack" a bool count; Python packs and round-trips it when the bool is true.
- AZ-2128 "TypeScript and Python presence not audited" hid real drops (G6).
- `fixtures/hostile/cases.txt` `empty_group_outside_flags` has no Python exemption; the exception lives in `README.md:972` and a test comment.
- The `boolflag` / `booltrue` rings cover only the single-bool scheme; the bool + value row (`010207`) is pinned by tests only in Rust and C++.
- Per-round bools (U2, G5) and split-form numbering (G4) are in no shared vector or ring.

FEATURE ASSESSMENT loop 12 round 1: CLARIFY — 19 covered / 11 out-of-scope / 6 gap-clear / 4 gap-unclear

## Round 2

**Date**: 2026-10-05
**Implement pass**: batch 02 (AZ-2129, AZ-2130, AZ-2131, AZ-2132, AZ-2133), batch report `_docs/03_implementation/batch_02_loop12_report.md`, commit 8b392c1 (diff `f4c92f0..8b392c1`)
**Verdict**: EXTEND — 13 covered / 12 out-of-scope / 1 gap-clear / 0 gap-unclear

**Owner decisions applied (not re-asked).** Round 1 answers U1 A, U2 A (deferred to AZ-2134), U3 A, U4 A; loop scope = bool follow-through (U1, U3, U4, G3). Deferred: G1 + G4 → AZ-2135, U2 + G5 → AZ-2134, G6 → AZ-2128 (extended), G2 → AZ-2127 (AC-4). Batch 2 review decisions: Rust public map `pack`/`unpack` exported and failing loudly; Rust nested-round rule narrower than Java's; Java typed empty nested row accepted as an AZ-2101 dependency.

**Method note.** `git archive 8b392c1` extracted into the scratchpad; suites re-run there (TS 108 + 3 todo, Python 103, Rust 135, C# 204, Java 0 failures, C++ all passed); the five `bitwhen` handoffs run with the ring's own functions; scratch probes in all six languages (C# and C++ also against `7a5a235`). No repository file touched.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| U1 | TypeScript `new Scheme(...)` runs every `scheme()` check | covered | AZ-2129 AC-1/AC-2. Tests: `typescript/tests/scheme-constructor.test.ts` (bool outside flags, wrong id, split bit outside scope, type number 256; same valid scheme as `scheme()`). Code: `typescript/src/index.ts:62-72`, `79-81` | round-1 U1 |
| U3 | An empty group that can never carry `true` fails construction wherever it stands (C#, Java, Python); groups that can carry it are unchanged | covered | AZ-2130 AC-1/AC-2, AZ-2131 AC-1/AC-2, AZ-2132 AC-1/AC-2. Tests: `csharp/tests/EmptyGroupTests.cs::*`; `BoolPlacementTest.java::emptyGroupWithoutFieldsIsRefusedEverywhere`, `::emptyNestedRowBitRoundTripsPresence`; `test_bool_placement.py::test_empty_group_is_scheme_error_everywhere`. Code: `csharp/Field.cs:190,199,204-211`; `java/.../SchemeOrder.java:105-110`; `python/src/packbin/_nodes.py:410-411`. C++ not covered: W1 | round-1 U3 |
| U4 | `bitwhen`: `{k:0,v:5}` → `010001`, `{k:1,v:5}` → `01010105`; project AC-4 reworded | covered | Project AC-4; AZ-2129/2130/2131 AC-4; AZ-2133 AC-1/AC-2. Tests in TS, C#, Java, Rust, C++; ring `language-pair.sh:108-112` (all five handoffs pass, consumers reject `01010105`). Python: W3 | round-1 U4 |
| G3 | A non-`true` value leaves the bit clear | covered | AZ-2129..2132 AC-3. Tests in TS, C#, Java, Python; Rust map `U8(2)` → `Type` (S11) | round-1 G3 |
| O9 | Python empty `group(anchor)` refused everywhere; meets `empty_group_outside_flags` | covered | AZ-2132 AC-1/AC-2; README exception removed | round-1 O9 |
| U2 | Per-round optional values in `repeat`/`times` | out-of-scope | Owner U2 A, deferred: AZ-2134 | round-1 U2 |
| G5 | C# drops values under `flags` in a round | out-of-scope | AZ-2134 | round-1 G5 |
| G1 | C++ binds a split bit to a byte read inside an earlier `when` | out-of-scope | AZ-2135 AC-2 | round-1 G1 |
| G4 | Split-bit numbering by field order in TS, C#, Java | out-of-scope | AZ-2135 AC-1 | round-1 G4 |
| G2 | Java nested-row group in a `repeat` round | out-of-scope | AZ-2127 AC-4 | round-1 G2 |
| G6 | TS/Python u2/bits/sized/packed-only flags groups | out-of-scope | AZ-2128 (extended) | round-1 G6 |
| D1 | TS: already-flattened fields build and pack through `new Scheme` | covered | AZ-2129 AC-2; `flatten` passes `flagByte`/`flagBit` through (`fields.ts:103-122`). Probe: `new Scheme(2, s1.fields)` → `020103070105` | batch 2 #1 |
| D2 | TS: unpack puts the flag byte value (`m: 1`) in the row | out-of-scope | AZ-2091 | batch 2 #2 |
| D3 | C#: an anchored empty group on a non-`bool` member is refused | covered | AZ-2130; `EmptyGroupTests.cs::Ac1_EmptyGroupOnANonBoolMember_FailsUnderFlags`; `Field.cs:199,204-211` | batch 2 #3 |
| D4 | C#: refusal in the `Field.Group` factory | covered | AZ-2130 AC-1; `Field.cs:190,199`; fluent `Fields<T>.Group` refused the same way | batch 2 #4 |
| D5 | Java: typed nested row throws `ClassCastException` on unpack | out-of-scope | AZ-2131 flagged concern (accepted-risk); AZ-2101 Defect 1 | batch 2 #5 |
| D6 | Java: empty nested row carries presence only | covered | AZ-2131 AC-2; `BoolPlacementTest.java::emptyNestedRowBitRoundTripsPresence`; README | batch 2 #6 |
| D7 | Rust: exported map `pack`/`unpack` reach the split form | covered | AZ-2133 AC-1; `flag_presence_tests.rs::bitwhen_*`; driver `handoff-rust/src/main.rs:141-195`; `lib.rs:18`, `walk/mod.rs:28,49`; README:278. Exception W2 | batch 2 #7 |
| D9 | AC-10 NFR failed once in a loaded container | covered | Project AC-10; NFR tests in C# and TS; batch 2 touched no hot path; re-runs pass | batch 2 #9 |
| D10 | Rust map: `times`/`when` as a `flags` member never written | out-of-scope | AZ-2128 flagged concern | batch 2 #10 |
| D11 | Rust map: `repeat`/`times` in a list/dict group element ignored | out-of-scope | AZ-2086 flagged concern | batch 2 #11 |
| V1 | Rust public `pack` fails loudly (`__repeat__` non-Groups; nested rounds that lose data) | covered | Owner decision; `rust/src/round_tests.rs::*` (10 tests); `walk/pack.rs:248`, `field/shape.rs:90-109,156,161`; README:978 | batch 2 review |
| V2 | Rust keeps `times` inside a `repeat` round; elements start outside any round | covered | Owner confirmed; `round_tests.rs::times_inside_a_repeat_round_still_builds`, `::repeat_and_times_inside_list_or_dict_elements_still_build`; `scope_tests.rs::times_count_reads_the_enclosing_scope` | batch 2 review |
| W1 | C++ `group(id)` with no children and no member builds directly in `flags` or as a `flag_bit`; its bit is always clear and unpack of a set bit drops it | gap-clear | Probe: `flags(0, group(0))` and `flag_byte(0), flag_bit(0, group(0))` compile, pack `0100`, unpack `0101` ok (same at 7a5a235). Code: `cpp/include/packbin/fields_grouped.hpp:22`, `order.hpp:182`, `src/core/values.cpp:54-56` | assess-round-2 |
| W2 | Rust public `pack` doc says every field inside a `times` takes one list item per round, but fields under `flags`/`when` inside a `times` round do not | out-of-scope | AZ-2086 Outcome / Included (per-round alignment for optional members). Probe: `times(n,[flags(f,[u8 x])])` → `01020000` (dropped); `times(n,[u8 k, when(k==1,[u8 x])])` → `Missing("x")` | assess-round-2 |
| W3 | Python not in the `bitwhen` ring | out-of-scope | AZ-2132 Problem; AZ-2100 | assess-round-2 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| W1 | Given C++ `scheme<Row>(1, flags(0, group(0)))` and `scheme<Row>(1, flag_byte(0), flag_bit(0, group(0)))`, where `group(0)` has no children and no member; When the scheme is compiled; Then it fails like `tests/compile-fail/empty_group_outside_flags.cpp`; and `flags(0, group<&Row::b>(0))` on a `bool` member still packs `0101` / `0100` | AZ-2130 owner decision U3: "any empty group that can never carry `true` fails construction wherever it stands. An empty group whose member is a `bool` / `bool?` stays a presence bit."; `README.md:974`: "Every package refuses a violation at construction" | new C++ task under AZ-2069 (1 point) |

### Not walked

- C# `List`/`Dict` whose element is `Flags` packs `00` for every item (members dropped); predates loop 12; no C# ticket (TS AZ-2102, Rust AZ-2085).
- Java empty nested row: any non-null member value (`false`, `0`) sets its bit (presence = non-null).
- TS `case "flags"` in `pack-fields.ts:197` and `walker.ts:272` no longer reachable through `Scheme` (constructor flattens): candidate dead code.
- README / `schema.md` do not mention the `bitwhen` behavior (only project AC-4 and the ring comment).
- Empty `flags(anchor)` with no members, across packages.
- Round-1 Not-walked items carry over.

### Harness gaps

- `implementation_report_bool_flag_limit_loop12.md` and `implementation_completeness_loop12_report.md` list only batch 1; no `batch_02_loop12_review.md` (review outcomes live in the batch report).
- `language-pair.sh` (boolflag, booltrue, bitwhen rings) is not run by CI; recorded only as DR6 in `_docs/04_refactoring/02-whole-project-assessment/discovery/components/08_drivers_embedded.md:60`, no ticket.
- AZ-2100 does not name the `bitwhen` vector.
- AZ-2090 and AZ-2091 still say their checks run "at `scheme(...)`"; after AZ-2129 they belong in the `Scheme` constructor.
- AZ-2086 does not name the Rust map `when`-inside-`times` symptom (W2); the public `pack` doc has no caveat for it.
- No ticket covers Rust nested-round parity once AZ-2127 lands in Java.
- `fixtures/hostile/README.md:28` still says an empty group is allowed inside `flags`, with no U3 exception.
- No test feeds already-flattened fields to `new Scheme`.
- Still open from round 1: the boolflag/booltrue rings cover only the single-bool scheme.

FEATURE ASSESSMENT loop 12 round 2: EXTEND — 13 covered / 12 out-of-scope / 1 gap-clear / 0 gap-unclear
