# Feature assessment — loop 13

loop: 13
feature: high-bug-fixes (epic AZ-2069: AZ-2084, AZ-2085, AZ-2086, AZ-2087, AZ-2088, AZ-2090, AZ-2091)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-05
**Implement pass**: batches 01–03 (commits `625c168`, `b4e8662`, `8d70244`), implementation report `_docs/03_implementation/implementation_report_high_bug_fixes_loop13.md`, batch reports `_docs/03_implementation/batch_0{1,2,3}_loop13_report.md`, completeness `_docs/03_implementation/implementation_completeness_loop13_report.md`
**Verdict**: CLARIFY — 44 covered / 31 out-of-scope / 13 gap-clear / 16 gap-unclear

**Intent baseline.** There is no loop-level `problem.md` and `scenarios.md` is absent for this loop (the specs were already in `todo/`). Baseline: the seven specs in `_docs/02_tasks/done/` (AZ-2084, 2085, 2086, 2087, 2088, 2090, 2091); the user decisions in `_docs/04_refactoring/02-whole-project-assessment/analysis/bugfix_task_plan.md`; project ACs `_docs/00_problem/acceptance_criteria.md` (AC-3: bytes identical across the six languages); `README.md` and `_docs/01_solution/schema.md`; the owner decisions of 2026-10-05 recorded in the batch reports (C# round slicing and aligned unpack pulled into AZ-2087; TypeScript round slicing pulled into AZ-2091; Rust F1/F2 fixed; C# shared `FlagGroup` as a follow-up; unpack memory growth accepted with a README note).

**Method note.** Four read-only analysts (TypeScript, Rust, C#, cross-language) read the specs, batch reports and code and ran scratch probes outside the repo (host toolchains on copies of `HEAD` and of the pre-loop commit `ce85fe0`). The parent merged the rows and wrote this report. No repository file was touched by the analysts. Ids: `T` TypeScript, `R` Rust, `C` C#, `X` cross-language; sources `bN#M` mean row M of batch N's Discovered table.

**Owner decision applied (2026-10-05, scope A).** The gaps this assessment found are not all fixed in loop 13. Included in this loop (rows marked `this loop`): AZ-2175 (C# `when` on written values and two pins), AZ-2176 (C# refuses nested rounds), AZ-2177 (TypeScript refuses nested rounds and pins `-0`), AZ-2178 (Rust typed `times` pins), AZ-2179 (cross-language rounds ring). Every other gap row is deferred: a follow-up ticket (AZ-2180 to AZ-2194) or a note on an existing ticket carries it, with the analysts' recommended option recorded as an open decision. The release number question for the Rust API break (R14) is asked at the tag confirmation.

### Coverage matrix

#### TypeScript (AZ-2084, AZ-2090, AZ-2091)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| T1 | A bigint into an f32/f64 field is refused | covered | AZ-2084 AC-3; `int-range.test.ts` "fraction and non-number throw"; `kinds.ts:284-286` | b1#1 |
| T2 | `-0` into u8/i8/u64 packs as 0 | gap-clear | Probe: `0100`, `0100`; production conforms (AZ-2084 Outcome 1); no test pins it. **→ AZ-2177 AC-4 (this loop)** | b1#2 |
| T3 | Range edges (u8 0/255, i64 ±2^63, u64 2^64-1, 2^53±1, f32 max, NaN/Inf) refuse or pass in every int/float kind and container position | covered | AZ-2084 AC-1..AC-4; `int-range.test.ts` "integer out of range throws", "range edges pack as before", "every container position is checked"; `kinds.ts:231-296` | spec |
| T4 | An unpacked u64/i64/float row packs again to the same bytes | covered | AZ-2084 AC-5; `int-range.test.ts` "64-bit unpacked row packs again"; `kinds.ts:252-296` | spec |
| T5 | pack throws mid-way leaves no partial state; the `PackSession` pad is unchanged | covered | AZ-2084 AC-1; `int-range.test.ts` "a refused session pack leaves the pad position alone"; `index.ts:87-92` | assess-step2 |
| T6 | A u64 count: pack takes a bigint for the field but `sized`/`packed`/`times` refuse it as a count; unpack of `01 0300000000000000 010203` gives `ok:false` | out-of-scope | AZ-2112 (todo; unpack only, pack leg unwritten there; note added to AZ-2112) | b1#3 |
| T7 | Python accepts numeric strings for floats; TypeScript refuses | out-of-scope | AZ-2084 Excluded line 3 + Flagged concern 1; follow-up AZ-2192 | spec flagged |
| T8 | Reference scope: nested group ids, later field / unknown id / element self-reference / count in an earlier `times` are construction errors; 64-bit `eq` matches both ways | covered | AZ-2090 AC-1..AC-5; `reference-scope.test.ts` "when naming a later field is a scheme error", "u64 when matches on unpack"; `ref-scope.ts:25-102` | spec |
| T9 | Existing schemes unchanged; `new Scheme` refuses what `scheme()` refuses | covered | AZ-2090 AC-6, AZ-2091 AC-7; `packbin.test.ts` golden hex, `borrowed-count.test.ts` route, `scheme-constructor.test.ts`; `index.ts:64-75` | spec |
| T10 | A count naming a bool or float is refused; `eq` may name any value field; a u2 slot is an integer | covered | AZ-2090 Rule 3; `reference-scope.test.ts` "count naming a bool is a scheme error", "a u2 slot is an integer"; `ref-scope.ts:51` | b2#1 |
| T11 | Which kinds may be `eq`/count sources: f32 `eq(0, 0.1)` packs `01cdcccc3d09`, own unpack `ok:false`; NaN never matches; `eq(u8,"1")` never matches | gap-unclear | Java, C++ and Rust limit sources to integer or bool; "decide with AZ-2126" was never written into AZ-2126. **Deferred → AZ-2126 (decision note added; recommendation: integer or bool only)** | b2#1 |
| T12 | `Scheme.fields` carries a bound reference copy (internal) | out-of-scope | AZ-2090 NFR holds (`index.d.ts` identical); release note at step 13 | b2#2 |
| T13 | Flags inside an unanchored or anchored group are packed and round-trip | covered | AZ-2091 AC-1, AC-2; `nested-group.test.ts` "flags inside a nested group are packed"; `fields.ts:280-299` | b2#3 |
| T14 | A split-form bit whose field is a group holding `flags`, and `flags` directly inside `flags`: inner values dropped on pack | gap-clear | Probe `{g:{a:5,c:2}}` → `01010500`; quote AZ-2091 Rule 2 "including inside groups". **Deferred → AZ-2183** | b3#4 |
| T15 | Member-name collision, group name equal to a child name, same-scope duplicates across `when` branches | covered | AZ-2091 AC-3..AC-5; `nested-group.test.ts` "nested member shadowing an outer member is a scheme error"; `member-names.ts:8-60` | spec |
| T16 | Two unanchored groups in exclusive `when` branches sharing a member are refused | covered | AZ-2091 rule; `nested-group.test.ts` "two unanchored groups sharing a member name is a scheme error"; `member-names.ts:40-43` | b3#9 |
| T17 | The flag-byte value is never a row member (short form, split form, inside `times`/`repeat`) | covered | AZ-2091 AC-6; `nested-group.test.ts` "unpacked row has no flag byte member"; `walker.ts:91-97` | spec |
| T18 | `repeat`/`times` pack by round index through `when`/`flags`/groups/u2; unpack gives one entry per round, `undefined` for a skipped one; same bytes on repack | covered | AZ-2134 AC-1, AC-2 (TS part) + AZ-2091 Outcome 5; `round-values.test.ts` "repeat packs each flags round by index", `round-roundtrip.test.ts`; `rounds.ts:12-119` | b1#4, b2#4 |
| T19 | A bool under flags in a round unpacks `true` / `undefined` | covered | AZ-2134 AC-1; `round-values.test.ts` "a bool under flags unpacks as true or absent"; `walker.ts:87-90` | b1#20 |
| T20 | A count read in a round is that round's value; a `when` in a round reads only its own round | covered | AZ-2090 scope rule; `round-values.test.ts` "a when in a round reads only the round's own value"; `walker.ts:52-55,112` | b3#10, b3#11 |
| T21 | Empty and zero-round data: repeat with no lists, `times` count 0 | covered | `round-values.test.ts` "repeat with no round leaves every key absent"; `rounds.ts:44-52` | assess-step2 |
| T22 | Hostile packets over round shapes still error (zero-progress, huge counts) | covered | AZ-2091 blackbox "hostile still errors"; `hostile.test.ts` zero-progress cases; `walker.ts:127-128,181-187` | assess-step2 |
| T23 | A lone scalar beside lists in a round is broadcast to every round (C# round 0 only) | gap-unclear | Pinned by a TypeScript test. **Deferred → AZ-2182 (cross-package decision, recommended: broadcast)** | b3#1 |
| T24 | `times` pack silently drops list entries beyond the count (`{n:2,v:[1,2,3]}` → `01020102`); C# throws | gap-unclear | **Deferred → AZ-2185 (recommended: refuse)**; sibling AZ-2186 Python, AZ-2187 Java | b3#2 |
| T25 | `when` / `times` as a `flags` member: bit never set on pack, value dropped | out-of-scope | AZ-2128 Flagged concern 1 (open); AZ-2120 is C# | b3#3 |
| T26 | A flat unpacked row of a group-under-flags holding only flags/u2/sized/bits/packed leaves the group bit clear and does not repack | out-of-scope | AZ-2128 Outcome + Problem table TypeScript row (note added) | b3#5 |
| T27 | A group written as a nested object inside a round counts present in every round (`{mark:{v:[7,undefined,9]}}` throws `missing v`) | gap-unclear | Loud, not silent. **Deferred: document that rounds take flat per-round lists (README, step 13); recommended A** | b3#6 |
| T28 | `repeat`/`times` nested inside a round: pack garbage or throws, unpack always errors | gap-unclear | AZ-2091 Excluded "owner decision pending". **Decided: refuse at construction → AZ-2177 (this loop)** | b3#7 |
| T29 | Same member name declared twice in one scope builds and loses a value | gap-unclear | AZ-2091 AC-5 allows same-scope duplicates. **Deferred → AZ-2188 (recommended: refuse reachable duplicates)** | b3#8 |
| T30 | Unpack memory is about packet bytes × names per round | out-of-scope | Owner-accepted (AZ-2091 Flagged concern 2); plan step 14 (security audit) | b3#12 |
| T31 | Upgrade notes pending (range errors, `fields` copies, row shape, widened accept set, no outer-name fallback, no `""` key) | out-of-scope | plan13 step 13 (update-docs) | b3#13 |
| T32 | Flat rows vs `Scheme<T>` typing (scan C4) | out-of-scope | AZ-2091 Excluded line 2 + Flagged concern 3 | spec flagged |
| T33 | A dict key equal to a member name overwrites that member on pack; a decoded `__proto__` key makes the row inherit members | gap-clear | Quote AZ-2091 Problem 2 "which one wins depends on the row's key order"; identical on `ce85fe0`. **Deferred → AZ-2184** | assess-step2 |
| T34 | Element error label is `$` for identity-accessor list/dict elements | out-of-scope | Error-label rule deferred (C15) | assess-step2 |

#### Rust (AZ-2085, AZ-2086)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| R1 | Two or more bound lists/dicts/`list_u16` keep their own members (pack and unpack) | covered | AZ-2085 AC-1, AC-2; `bound_names_tests.rs::two_bound_lists_pack_their_own_members`; `scheme/mod.rs:123-130` | spec |
| R2 | F-AC-1 user row bytes unchanged; AC-10 loop under 1 s | covered | AZ-2085 AC-3; `scheme_tests.rs::user_handler_reads_first_byte`; wire path `walk/pack.rs` untouched | spec |
| R3 | `when` matches by integer value at any width/sign (u64 above i64::MAX) | covered | AZ-2085 AC-4; `field_id_tests.rs::field_id_when_matches_a_wider_eq_value_by_number`; `value.rs:86-104` | spec |
| R4 | `when` on a float/utf8/bytes source or non-integer `eq` refused at construction | covered | AZ-2085 AC-5; `integrity_tests.rs::when_on_a_float_source_is_refused`; `field/integrity.rs:74-83`. README note at step 13 | b1#7 |
| R5 | Composite list/dict elements refused; single-value elements still build | covered | AZ-2085 AC-6; `integrity_tests.rs::list_of_flags_is_refused`, `::single_value_elements_still_round_trip`; `integrity.rs:85-103` | b1#6 |
| R6 | Hostile typed list/dict (invalid utf8, oversize count, bad key) is `Err`, no panic | covered | AZ-2085 AC-6 blackbox; `bound_names_tests.rs::hostile_oversize_count_through_a_typed_list_is_an_error`; `walk/element.rs:46` | spec |
| R7 | Typed `times`: README vector, 4 rounds, count 0 and 1, count 0 replaces a non-empty default Vec | covered | AZ-2086 AC-1, AC-2; `times_tests.rs::ac1_readme_times_vector_packs_and_unpacks`; `scheme/times.rs:25-70` | spec |
| R8 | Count and Vec length disagree: `PackError` naming the `times`, no bytes | covered | AZ-2086 AC-3; `times_tests.rs::ac3_count_larger_than_the_vec_names_the_times`; `walk/pack.rs:338-343` | spec |
| R9 | Optional/conditional members keep their round (typed flags, `when`, utf8, `bool_flag`; map R-P6) | covered | AZ-2086 AC-4; `times_tests.rs::ac4_typed_optional_member_keeps_its_round`; `scheme/times.rs:43-60` | spec |
| R10 | Typed route fixture both ways (packed count shared with `times`) | covered | AZ-2086 AC-5; `times_route_tests.rs::ac5_typed_route_matches_the_fixture_both_ways` | spec |
| R11 | Hostile `times` counts (u32 max, i8 -1): `Err`, fast, no pre-sized Vec | covered | AZ-2086 AC-6; `times_route_tests.rs::ac6_oversize_count_through_a_typed_times_is_short`; `unpack.rs:317` | spec |
| R12 | README times/route bytes identical to the other five packages | covered | AZ-2086 AC-1/AC-5 blackbox; the same hex pinned in each package's tests (pins, not a ring; ring tracked in AZ-2179 for rounds) | spec |
| R13 | Public API `SchemeItem::times(anchor, count_id, get, set, members)`; the 3-argument form and the struct variant removed | covered | Owner decision "Fix it"; `times_tests.rs` R7-R11; `scheme/mod.rs:79-93` | b2#5 |
| R14 | The old 3-argument `SchemeItem::times` shipped in tag `v0.2.1` and is removed; no CHANGELOG; the README Rust section says nothing on typed `times` | gap-unclear | Options: next tag a minor (0.3.0) with the new signature in the README; or 0.2.x with a README note; or a deprecated shim (the old form never worked past count 1). **Asked at the v0.2.2 tag confirmation; README note at step 13** | assess-step2 |
| R15 | Map form returns per-name lists plus `__times_<anchor>` Groups; pack with both refuses a list that disagrees with the rounds | covered | AZ-2086 AC-4 + review F2; `times_tests.rs::map_edited_list_beside_the_rounds_fails_pack`; `walk/times.rs:21-52` | b2#6 |
| R16 | Typed element panics (outer reference, wrong ids) now fire in `Scheme::new` | covered | AZ-2086 AC-1; `times_tests.rs::element_reference_to_an_outer_field_is_refused`; `scheme/times.rs:36` | b2#10 |
| R17 | A `times` nested in a `times` element is refused at construction | covered | AZ-2086 flagged (accepted-risk); `round_tests.rs::typed_times_inside_times_is_refused`; `shape.rs:100-108` | spec |
| R18 | `eq` on a bool with a non-true value: typed packs nothing, map packs members its own unpack rejects | out-of-scope | AZ-2126 (user decision 2026-10-05) | b1#5 |
| R19 | A `when` or count naming a field inside an earlier `times`/`repeat` body, or a name never declared, builds and never fires | gap-clear | Quote README "A field inside a repeat or times is not visible after it"; identical on `ce85fe0`. **Deferred → AZ-2117 (ACs added)** | b1#8 |
| R20 | Dead placeholder names, redundant early `repeat` panics, duplicated `as_int`, weak AC-6 tests (review Lows) | out-of-scope | Batch 1 review F2, F3, F4, F6 not applied; no usage impact | b1#9 |
| R21 | Typed binders for `repeat`, `u2`, flag byte, generic list/dict remain missing | out-of-scope | AZ-2085/AZ-2086 Excluded (C18 undecided) | spec flagged |
| R22 | `list_u16` keeps an `element_id` argument that must be 0 | out-of-scope | AZ-2085 Excluded (C18/C13) | spec flagged |
| R23 | Unpack memory about 480 bytes per round-byte (1 MB of 1-byte rounds: 506 MB peak) | out-of-scope | Owner-accepted (batch 2 review F3); plan step 14 (security audit); README note | b2#7 |
| R24 | A `times` as a `flags` member builds but its bit never sets | out-of-scope | AZ-2128 Flagged concern (open; note added) | b2#8 |
| R25 | A map scheme reusing one member name in two `times` cannot repack unedited values (loud) | out-of-scope | Batch 2 Discovered 9 (HEAD identical, errors loudly) | b2#9 |
| R26 | Hand-built map `times` fed per-name lists with a member under flags/`when` drops it silently | gap-unclear | **Deferred → AZ-2189 (recommended: `PackError::Type`)** | assess-step2 |
| R27 | A raw `SchemeItem::Field(repeat/when/flags …)` in a typed scheme packs nothing, drops on unpack | out-of-scope | C18 typed `repeat` (AZ-2086 Excluded) | assess-step2 |
| R28 | `PackSession::pack` of a typed `times` row with a mismatch returns plain `None` | out-of-scope | AZ-2105 AC-2 | assess-step2 |
| R29 | One `Scheme<T>` cannot be shared across threads (`Rc<str>`) | out-of-scope | Identical at `ce85fe0`; no loop 13 change | assess-step2 |
| R30 | The pack error label for a typed list/dict over 65535 items is an internal name | out-of-scope | AZ-2085 Excluded (C15) | assess-step2 |
| R31 | Working but unpinned shapes: sibling `times` sharing a count, `times` in a `when` body, `sized` with an element-local count, u16 count 300, 255 rounds × 8-member flags, `Vec<u8>` and tuple elements, session round trip | gap-clear | Quote AZ-2086 "Element items may be any typed item a top-level row supports". **→ AZ-2178 (this loop, tests only)** | assess-step2 |

#### C# (AZ-2087, AZ-2088)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| C1 | Pack reads each round value by index through when/flags/flag bits/groups (`01030102020303`, `0103030102020303`, `010101050200`) | covered | AZ-2087 AC-4 + Outcome (U2), AZ-2134 AC-1..3; `RoundValueTests.cs::Repeat_FlagsRound_PacksEachRoundByIndex`; `Walker.Rounds.cs:9-126` | b1#10 |
| C2 | Aligned unpack (null for a skipped round), repack the same bytes, zero rounds leave keys absent | covered | AZ-2087 Outcome (U2); `RoundValueTests.cs::Repeat_NoRounds_LeavesTheKeysAbsentAndRepacksTheSameBytes`; `Walker.Rounds.cs:128-134` | b1#10 |
| C3 | `when`/count must name an earlier field of the same scope | covered | AZ-2087 AC-1..AC-5; `ReferenceScopeTests.cs::When_NamingALaterField_FailsConstruction`, 3 hostile vectors; `Packbin.cs:188-247` | spec |
| C4 | Pack throws `ArgumentException` naming member and id for a missing value, ragged repeat, short or long `times` list, absent list/dict/sized | covered | AZ-2088 AC-1, 3, 4; `LoudPackTests.cs::Pack_RequiredValueMissing_ThrowsNamingTheMemberAndItsId`; `Walker.Presence.cs:45-51` | b1#17 |
| C5 | A field declared for another row type is refused at construction (also a child-row field in the parent scheme) | covered | AZ-2088 AC-5; `SchemeOwnershipTests.cs::Construct_FieldDeclaredForAnotherRowType_ThrowsNamingBothTypes`; `Packbin.cs:266-271`. README note at step 13 | b2#12 |
| C6 | Float `when` never throws; NaN equals NaN, -0.0 differs from 0.0 | covered | AZ-2088 AC-6; `FloatWhenTests.cs::PackAndUnpack_FloatWhen_NeverThrowsAndWritesOnlyOnAMatch`; `Walker.cs:345-361` | b2#16 |
| C7 | A scheme copies its fields; shared Field/Condition not re-bound; many threads on one shared condition | covered | AZ-2088 AC-7, AC-8; `SchemeOwnershipTests.cs::Schemes_SharingAConditionAndAField_PackAndUnpackTheirOwnBytesFromManyThreads`; `Packbin.cs:69,188-197` | spec |
| C8 | Pack throws mid-way: no bytes returned, the caller's dictionary untouched | covered | AZ-2088 AC-1 + NFR; `LoudPackTests.cs::Pack_RequiredValueMissing_ThrowsNamingTheMemberAndItsId`; `Packbin.cs:119-126` | assess-step2 |
| C9 | `PackSession.Pack` that throws must not advance the counter | gap-clear | Code is right (`PackSession.cs:45-47`), no test; quote README line 368 "must deliver packets in order and drop none". **→ AZ-2175 AC-4 (this loop)** | assess-step2 |
| C10 | Aligned unpack memory and time about packet bytes × names per round (8x time too) | out-of-scope | Owner-accepted (AZ-2087 Flagged concern, accepted-risk); README note; plan step 14 | b1#11 |
| C11 | Typed-row `Unpack` of any repeat/times row throws `InvalidCastException`; no public C# API can read more than one round | out-of-scope | AZ-2092 Excluded + open Flagged concern (note added); README line 973 says unpack does not throw | b1#12, b2#18 |
| C12 | The decoy-row-type hack (the only typed way to receive round lists) is now refused at construction | out-of-scope | AZ-2092 open concern (note added); upgrade note at step 13 | assess-step2 |
| C13 | README C# `List<Role>` example fails on pack | out-of-scope | AZ-2092 AC-2; identical on `ce85fe0` | b2#15 |
| C14 | A lone `byte[]`, `List<int>` or non-`IList` collection for a Bytes/Sized/Bits/Packed value in a round is read as a list of rounds (`InvalidCastException` or misleading message) | gap-unclear | **Deferred → AZ-2182** | b1#13, b2#13 |
| C15 | A lone scalar in a round goes to round 0 only; Java and TypeScript broadcast | gap-unclear | **Deferred → AZ-2182 (recommended: broadcast)** | b1#15 |
| C16 | `repeat`/`times` nested in a round: values not packed from the outer round (silent for `repeat>repeat`, misleading throw for `times` in `repeat`) | gap-unclear | **Decided: refuse at construction → AZ-2176 (this loop)** | b1#14 |
| C17 | `when` naming a field an earlier `when` skipped: pack evaluates it on supplied values, unpack sees it absent; in rounds the packet is accepted with wrong data (`01 00 03` reads K=[0,3]; HEAD refused it) | gap-clear | Quotes README line 796 "The tested field must already have been read", AZ-2088 NFR "Pack either returns bytes the peer can read, or throws"; Java evaluates on `seen`. **→ AZ-2175 AC-1, AC-2 (this loop)** | b2#14 |
| C18 | A count naming a non-integer field (utf8, bytes, f64, bool) builds and fails at pack with a raw exception | gap-clear | Quotes README lines 639, 932 "N is an earlier integer". **Deferred → AZ-2181** | b1#18 |
| C19 | `when` target kinds: C# accepts float, bytes, utf8, bool; Java/C++ integer or bool, Rust refuses non-integer, TypeScript any | gap-unclear | AZ-2088 AC-6 mandates the float `when`. **Deferred → AZ-2126 (decision note added)** | b1#18, b2#1 |
| C20 | `when` as a flag-bit inner never sets its bit | out-of-scope | AZ-2120 | b1#19 |
| C21 | A list/dict element that is a continuing group throws `KeyNotFoundException` on unpack | out-of-scope | AZ-2119 | b1#16 |
| C22 | A bool under flags unpacks `[true,null,true]`; the Python half is AZ-2134 | covered | AZ-2134 AC-1; `RoundValueTests.cs::Repeat_FlagsRound_UnpacksOneEntryPerRoundAndRepacksTheSameBytes`; `Walker.Rounds.cs:128-134` | b1#20 |
| C23 | `FlagGroup` stays shared: `flagByte.Bit(x)` after construction changes a built scheme | out-of-scope | Owner decision 2026-10-05: follow-up **AZ-2180**; AZ-2135 covers only the shared bit counter | b2#11 |
| C24 | Float equality across languages (NaN, -0.0) | out-of-scope | AZ-2088 Flagged concern (C15/docs, open Low) | spec flagged |
| C25 | Pack now throws where it silently dropped data | covered | AZ-2088 NFR Reliability; `LoudPackTests.cs`; `Walker.Presence.cs:45-51`. README upgrade note pending | spec flagged |
| C26 | The same member name at top level and in a round body (dictionary rows) | out-of-scope | AZ-2092 Excluded; TypeScript refuses at construction (AZ-2091 AC-5) | assess-step2 |
| C27 | An optional name with a shorter list than the round count is accepted, padded as absent | covered | AZ-2087 AC-4, AZ-2134 U2; `LoudPackTests.cs::Pack_WhenFalseInTheRoundsWhereTheValueListRanOut_StillPacks`; `Walker.Rounds.cs:105-126` | assess-step2 |
| C28 | AC-10 speed after loop 13 | covered | Project AC-10; `PackbinTests.cs::Nfr_RoundTripsWithinOneSecond`; probe typed 530 ms (HEAD 514) | assess-step2 |
| C29 | Split-form `FlagByte`/`Bit` (incl. bool) inside a round: pack by index, aligned unpack, repack | gap-clear | Works (`01 03 01 02 01 03`) but only a build test exists. **→ AZ-2175 AC-5 (this loop)** | assess-step2 |

#### Cross-language (X)

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| X1 | Aligned rounds have no cross-language byte check; `language-pair.sh` has no ring using `repeat`/`times` | gap-clear | Quotes AZ-2134 AC-1 (same bytes in all packages), project AC-3. **→ AZ-2179 (this loop)** | assess-step2 |
| X2 | The cross-language rings are not run by CI at all | gap-unclear | No reference in `test.yml`, `publish.yml`, `docker-compose.test.yml`. **Deferred → AZ-2193 (recommended: a CI job)** | assess-step2 |
| X3 | Rust builds a `when`/count naming a field inside an earlier `repeat`/`times` body; value silently lost (TypeScript, C#, Java refuse) | gap-clear | Quote README "A field inside a repeat or times is not visible after it". **Deferred → AZ-2117 (ACs added)** | assess-step2 |
| X4 | Python builds the `when_names_outer_field_in_repeat` scheme | gap-clear | Quote `cases.txt` `when_names_outer_field_in_repeat construct scheme_error`. **Deferred → AZ-2113 (ACs added)** | assess-step2 |
| X5 | `times` list longer than its count is dropped silently in TypeScript, Python, Java | gap-clear | Quotes README "The inner fields, exactly N times", AZ-2088 AC-3. **Deferred → AZ-2185, AZ-2186, AZ-2187** | assess-step2 |
| X6 | `when` on a float: three packages build it and disagree on -0.0/NaN, three refuse | gap-unclear | **Deferred → AZ-2126 (recommended: integer or bool only everywhere)** | b1#18, b2#1 |
| X7 | A lone scalar in a multi-round list name (broadcast / round 0 / refuse) | gap-unclear | **Deferred → AZ-2182** | batch notes |
| X8 | `repeat`/`times` nested in a round: TypeScript silent corruption, C# loud, Java/Rust refuse | gap-unclear | **Decided: refuse in TypeScript and C# → AZ-2177, AZ-2176 (this loop)** | b3#7 |
| X9 | Dynamic-row pack strictness beyond TypeScript (C# dict path, Java incl. `BigInteger` wrap, Python floats) | gap-unclear | architecture.md line 115 "pack refuses an integer that does not fit". **Deferred → AZ-2190 (Java), AZ-2191 (C#), AZ-2192 (Python)** | assess-step2 |
| X10 | Unpack memory/time amplification of aligned rounds (TypeScript 419 MB, C# 556 MB, Rust typed 325 MB, Java 540 MB RSS per MB of packet) | out-of-scope | Owner-accepted; plan step 14 | b3#12 |

### Gaps that need a decision (gap-unclear)

Owner scope A (2026-10-05) answered the scope question for all of them: only the nested-round refusal (C16/T28/X8) is decided and implemented in this loop. The rest are deferred with the recommended option recorded as an `open` decision in the follow-up ticket; they are asked again when that ticket is taken.

- **Lone value in a round (T23, C14, C15, X7) → AZ-2182.** What should a lone scalar, `byte[]` or list given for a name in a round mean? A) broadcast a lone scalar to every round everywhere, and make a lone `byte[]`/collection a loud error naming the field (TypeScript and Java already broadcast; only C# changes); B) refuse when there is more than one round; C) round 0 only. Recommendation: A.
- **Source kinds for `when` and counts (T11, C19, X6, C18) → AZ-2126, AZ-2181.** Integer or bool only everywhere (Java, C++, Rust already), or keep floats open with a defined equality rule? Recommendation: integer or bool only.
- **`times` list longer than its count (T24, X5) → AZ-2185, AZ-2186, AZ-2187.** Refuse like C#, or keep the count as the authority? Recommendation: refuse.
- **Duplicate member name in one scope (T29) → AZ-2188.** Leave, refuse reachable duplicates, or refuse all but `when` siblings? Recommendation: refuse reachable duplicates.
- **A nested-object group in a round (T27).** Document that rounds take flat per-round lists (today it throws), accept nested objects (reopens the flat-row design), or refuse an unanchored group in a round? Recommendation: document (README, step 13).
- **Hand-built Rust map `times` lists under flags/`when` (R26) → AZ-2189.** Loud error (recommended), documented limit, or an aligned list value.
- **CI for the cross-language ring (X2) → AZ-2193.** One CI job with all six toolchains (recommended) or keep it a manual release gate.
- **Dynamic-row pack strictness (X9) → AZ-2190, AZ-2191, AZ-2192.** Refuse what does not fit in the Java, C# and Python dynamic-row paths (recommended: yes, the cheap cases).
- **Release number for the Rust API break (R14).** Asked at the `v0.2.2` tag confirmation.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | owner task |
|----|------------------------------|--------------|------------|
| C17 | Given `U8 Profile(0), When(1, Eq(0,0), U8 Shape(1)), When(2, Eq(1,0), U8 Detail(2))` and `{Profile=1, Shape=0, Detail=4}`, When packed, Then `01 01` and unpack returns the row; in a round K=[0], A=[5], B=[3] packs `01 00` | README line 796 "The tested field must already have been read."; AZ-2088 NFR "Pack either returns bytes the peer can read, or throws" | **AZ-2175 (this loop)** |
| C9, C29 | PackSession after a failed pack, and a split-form flag byte round (`01 03 01 02 01 03`) | README line 368; AZ-2087 Outcome "flag bits" | **AZ-2175 (this loop)** |
| T2 | `-0` into u8, i8, u64 packs `0100`, `0100`, `010000000000000000` | AZ-2084 Outcome 1 | **AZ-2177 (this loop)** |
| R31 | Seven unpinned typed `times` shapes pack to the probe bytes | AZ-2086 Included | **AZ-2178 (this loop)** |
| X1 | `roundflags` and `roundwhen` rings agree across packages | AZ-2134 AC-1; project AC-3 | **AZ-2179 (this loop)** |
| T14 | Flags under a split bit / inside flags are packed (`01010101 02`) | AZ-2091 Rule 2 | AZ-2183 (deferred) |
| T33 | Dict keys do not flatten into the row | AZ-2091 Problem 2 | AZ-2184 (deferred) |
| R19, X3 | A `when`/count naming a field in an earlier body, or an undeclared name, fails at construction in Rust | README "A field inside a repeat or times is not visible after it" | AZ-2117 (deferred, ACs added) |
| X4 | Python refuses an outer reference inside a repeat | `cases.txt` `when_names_outer_field_in_repeat` | AZ-2113 (deferred, ACs added) |
| X5 | `times` list longer than its count is refused in TypeScript, Python, Java | README "exactly N times"; AZ-2088 AC-3 | AZ-2185, AZ-2186, AZ-2187 (deferred) |
| C18 | A non-integer count fails at construction in C# | README lines 639, 932 | AZ-2181 (deferred) |

### Not walked

- A `times` with a huge borrowed count and an optional-only body loops count times and grows the output (pre-existing, TypeScript).
- Typos in row keys silently clear optional flag bits (pre-existing; C# analogue is AZ-2088).
- Developer-chosen member names `__proto__` / `constructor` in TypeScript rows; class-instance rows with prototype getters; handler re-entrancy tests.
- `_docs/01_solution/schema.md` TypeScript snippets use a stale API (`flags([…])` without an anchor).
- C# `Convert.ToInt32` overflow for a count above `int.MaxValue`; a null `params Field[]` element; `Condition.Eq(.., byte[])` aliases the caller's array (code reading, unverified).
- C# NaN packs with a sign bit (`…f8ff`) where the others give `f87f` (AZ-2084 AC-4 specifies `c07f`; pre-existing).
- Rust typed big-endian ints (C18); a count naming an optional or utf8 field (loud); `E: !Default`.
- C++ rounds and range cells were not probed (source reading only).

### Harness gaps

- `language-pair.sh` is manual and none of its rings used `repeat`/`times` (AZ-2179 adds the two rings; AZ-2193 would run it in CI).
- `fixtures/hostile/cases.txt` has no `pack` stage (AZ-2194).
- No amplification guard: the C# 1 MB / 36-name body takes 1.6–1.8 s, above the 1 s limit the hostile README sets for unpack cases (vectors are tiny, so nothing trips); plan step 14 covers it.
- The position ring only packs; AC-2 and "the flag byte is not a row member" are per-package only.

### Docs gaps

Handled by plan step 13 (update-docs): README lines on reference scope (now all six packages), the "If you upgrade" block (TypeScript range errors and name collisions, C# foreign-row-type and loud pack, aligned rows in C#/TypeScript, Rust composite elements and non-integer `when`, `SchemeItem::times` signature and the `__times_<anchor>` key, unpack memory multiplier), README Integers/Floats/Repeat/Times sections, `schema.md` lines 16–19, 167, 188, 194, the three component descriptions, `fixtures/hostile/README.md:132`, and the `v0.2.0` wording in the AZ-2084/2086/2091 risk sections (tag `v0.2.1` is already out; the README upgrade block is the only release-notes vehicle).

### Harness note

Batch reports 1–3 all carry the mandatory `## Discovered during implementation` table (20, 18 and 14 rows).
