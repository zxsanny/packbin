# Batch Report

**Batch**: 1 (loop 18, wave 1: one worker per package directory, seven worker stages)
**Tasks**: AZ-2126 (construction check, six packages), AZ-2304, AZ-2305, AZ-2306, AZ-2307, AZ-2308, AZ-2309, AZ-2310, AZ-2311; AZ-2135 closes with AZ-2304
**Date**: 2026-10-10

Workers: C# A (AZ-2305, 2306, 2308, 2309, 2310), TypeScript, Rust, Java, Python, C++, C# B (AZ-2126, AZ-2307, ring files). Owner direction (2026-10-06): no per-batch review and no per-batch Docker run; each worker ran only its own package suite; one total review and one total test run follow at the end of the loop. Owner decisions of 2026-10-10 (accept all recommended) are in `plan18.md`.

## Task Results

| Task | Status | Packages | Tests | Issues |
|------|--------|----------|-------|--------|
| AZ-2126_eq_bool_true_only | Partial: construction check done in all six; the `eq_bool_false` vector and README section are wave 2 | all six | TypeScript `eq-source-kinds` 32 total new with AZ-2308; Python `test_when_count_sources` 45; Java `EqBoolTrueOnlyTest`; Rust `eq_bool_true_tests`; C++ `source_kinds_host_tests` + compile-fail `when_eq_bool_false`; C# `EqBoolTrueOnlyTests` | decided concern widened it: `when` sources integer or bool only, counts integer only (TypeScript, Python, Rust, C++, Java, C# each changed only where they differed) |
| AZ-2304_cpp_flag_byte_scope_members | Done | cpp | `flag_scope_host_tests` + 2 compile-fail | new `unpack_scoped` function: flash not measured yet |
| AZ-2305_csharp_collection_member_checked | Done | csharp | `CollectionMemberTests` | check skipped inside rounds (discovery 12) |
| AZ-2306_csharp_empty_nested_row_present | Done | csharp | `EmptyNestedRowTests` | none |
| AZ-2307_csharp_flags_element_and_rings | Done; the rings run in step 11 | csharp, `.github` ring files | `FlagsElementTests`; `ring-wiring.test.sh` passes | the C# handoff driver was broken by AZ-2305 and was fixed here |
| AZ-2308_lone_dict_in_round_refused | Done | csharp, typescript, python, java, rust (C++ not applicable: typed array rounds) | `LoneDictRoundTests`, `lone-dict-in-round.test.ts`, `test_lone_dict_in_round.py`, `LoneDictRoundTest`, `times_lone_value_tests` | probe table below |
| AZ-2309_csharp_numeric_slots_strict | Done | csharp | `StrictSlotTests` | none |
| AZ-2310_csharp_dict_pack_repack_and_bytes_int | Done | csharp | `DictRepackTests` | none |
| AZ-2311_rust_times_lone_scalar | Done | rust | `times_lone_value_tests` | none |

## Probe table (AZ-2308 AC-1): a lone dictionary for a `Dict` name in a round, before this batch

| Package | Before | After |
|---------|--------|-------|
| C# | broadcast to every round | `ArgumentException` naming the member |
| TypeScript | object: broadcast; `Map`: an empty dictionary per round; `repeat`: one round | error naming the member |
| Python | `times`: broadcast; `repeat`: one round, or `ValueError` for unequal lengths | `TypeError` naming the member (also with `times` count 0) |
| Java | broadcast (`times`) or one round (`repeat`) | `IllegalArgumentException` naming the member |
| Rust (map API) | n=1 packed; n=2 `Missing` | `PackError::Type` naming the member |
| C++ | not applicable (typed array rounds) | unchanged |

## Code Review Verdict: not run for this batch (owner direction); covered by the one total review of loop 18

## Test Suite (each worker, own package, before to after)

- C#: 649 to 749 passed, on net10.0 and on `netstandard2.0`
- TypeScript: 470 to 502 passed; strict `tsc --noEmit` exit 0
- Python: 492 to 549 passed (the note of 326 in earlier reports is stale)
- Rust: 360 to 390 passed
- Java: suite passes (it prints no counts; `expect(` call sites 1125 to 1152)
- C++: `make -C cpp test` passes (`expect(` call sites 257 to 278; compile-fail cases 11 to 14); embedded stages not run (step 11)
- `bash fixtures/hostile/cases.test.sh`, `ring-wiring.test.sh`, `report-row.test.sh`: pass
- `language-pair.sh` rings, embedded ARM/ESP, publish gate: not run (step 11)

CI-parity: PASS for the language suites (the same `run-suite.sh` commands each worker ran) and the three shell checks above; the rings, the embedded job and the publish gate are the one total run.

## Existing tests changed or removed (the decided concern reverses them; none weakened)

- C#: `FloatWhenTests` deleted (its integer-source cases moved to `FloatConditionValueTests`); `WrittenWhenKindsTests` lost its bytes, sized, bits, packed and utf8 cases; `WrittenWhenTests.Ac7` uses `Eq(0,true)`; five tests deleted because their scheme can no longer be built (a zero-width field cannot be a `when` source): `HostileUnpackTests.Ac1_RepeatBodyWithANeverMatchingWhen_ReturnsTrailingBytes`, `Reliability_ConditionOnNaNFloat_DoesNotThrow`, `Counts.Times_NeverTrueWhenBodyWithU32MaxCount_ReturnsShortPacketQuickly`, `ZeroWidthElementTests.NeverMatchingWhenListElement_IsError`, `NeverMatchingWhenDictValue_IsError`; `NestedRoundTests.ATimesInADictElementInARound_Builds` bound a `Dict` field to a `List<object?>` member (a test mistake, now a `Dictionary` member).
- TypeScript: `reference-scope.test.ts` (sized/bits/packed `eq` cases became refusals), `when-on-written-values.test.ts` (`eq(bool,false)` and f32 `eq` tests removed), `support/hostile-cases.ts` `emptyRound` without a never-matching `when`.
- Python: `hostile_support.py::_empty_round`, `test_zero_width_elements.py::test_never_matching_when_in_a_group_element_is_error` became `test_group_of_zero_width_element_is_error`.
- Rust: `when_written_tests::ac3_eq_false_on_a_clear_bit_does_not_write_its_body` became `ac3_eq_false_on_a_bool_is_refused_at_construction`; `times_longer_tests::ac7_a_lone_value_for_a_member_is_still_missing_after_round_zero` became `..._is_in_every_round` (`01020505`).
- Java: `ReferenceScopeTest`: count message suffix only. C++: none. Environment: the stale Linux binary `cpp/build/packbin_tests` (gitignored) was deleted.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A lone byte buffer for a `Bytes` or `Sized` name in a round is broadcast in TypeScript, Python, Java and Rust and refused in C# | AZ-2182 option A, AZ-2308 | owner decision: refuse everywhere or broadcast everywhere | unclear |
| 2 | TypeScript packs a `Map` given as a dict outside a round as an empty dictionary (`isPlainObject(Map)` is true) | AZ-2308 | spec: refuse a `Map` for a dict name | unclear |
| 3 | Sibling members of one `flags`: TypeScript, Java and now C++ give each member its own flag-byte scope; Rust shares one scope across the members | AZ-2304 | decide whether Rust changes (small) or C++, TypeScript and Java do | unclear |
| 4 | C++: a group under `flags` whose only children are `flag_byte` and `flag_bit` is never present on pack; the "x only" row `0100010105` of Rust and TypeScript cannot be written | AZ-2304 | follow-up spec: presence of a flag-bit child in a group under `flags` | unclear |
| 5 | C++ refuses a `when` that names an empty group (`group<M>(id)`) for every value, even `true`; Rust accepts an empty group as a bool source | AZ-2126 | accept `eq(emptyGroup, true)` in C++ for parity, or document the refusal | unclear |
| 6 | C++ errors carry one field id: a bad `when` reports the `when` id, not the source field id | AZ-2126 / C15 | none unless C15 asks | unclear |
| 7 | Rust has no bool value: false is `U8(0)`, true is any integer equal to 1, so `eq(bool, true)` is `eq(id, 1)`; a count may name a `flags` or flag-byte name | AZ-2126 | README upgrade note | clear |
| 8 | Python refuses a lone dictionary even when the `times` count is 0 (matches how an over-long list is refused) | AZ-2308 | keep; reverse by moving the check into the per-round reader if a package disagrees | unclear |
| 9 | C# `ElementValues`: a member a group element lacks is inherited from the outer row's values of the same name (fixed only for flags elements) | AZ-2307 | later task: members-only rule for group elements | unclear |
| 10 | The AZ-2305 rule: a float, double or decimal member is accepted for an integer field; `IList<E>`, `IList`, `IDictionary<string,E>`, `IDictionary` are accepted, `IEnumerable<E>` is not; an integer member must contain the field's whole range | AZ-2305 | owner to confirm | unclear |
| 11 | `language-pair.sh` ring order is a chain (typescript to python to java to csharp to typescript), not all pairs, per ring; AZ-2307 AC-2 wording read as membership | AZ-2307 | say if all pairs are wanted (18 more handoffs) | unclear |
| 12 | The AZ-2305 collection check is skipped for list and dict fields inside a round; typed `Unpack` of a round still throws `InvalidCastException` (F17) | AZ-2305 | leave; F17 stays open | clear |
| 13 | Whether other packages round fractions in `u2` slots, `bits` and `packed` items was not probed | AZ-2309 | probe in the next loop | clear |
| 14 | `/tmp/packbin-pytest` is broken (no `pyvenv.cfg`, pytest has only `__pycache__`); `run-suite.sh` checks only `bin/pytest` | harness | rebuild the shared venv or make the script check the import | clear |
| 15 | `dotnet test csharp` without `MSBUILDDISABLENODEREUSE=1` hangs at 646 of 649 (a test starts a child `dotnet build`); now in `AGENT_GOTCHAS.md` | harness | done | clear |
| 16 | `Walker.Counted.cs` is 480 lines (cap 500); C# `Packbin.cs` 417 | maintainability | split before the next addition | clear |
| 17 | Error text is each package's own wording (C15) | AZ-2126 | align if C15 defines a format | clear |
| 18 | The C# handoff driver `NestedScheme` used one member as a list and a dict; AZ-2305 refused it and the CI `user`/`nested` ring pairs would have failed; fixed in the driver | AZ-2307 | done | clear |

## Behavior changes for the upgrade notes

- All six: a `when` with `eq(bool, v)` where `v` is not `true` fails at scheme construction (it never matched on unpack); a `when` naming a float, utf8, bytes, sized, bits or packed field fails at construction (C# AZ-2088 AC-6, a float `when`, is reversed); a count naming a bool or a non-integer field fails at construction (Java, Rust and C++ used to accept a bool).
- A lone dictionary for a `Dict` name in a `repeat` or `times` round is refused in C#, TypeScript, Python, Java and Rust (it was broadcast or read as one round); a list with one dictionary per round packs as before.
- Rust map `times`: a lone scalar goes to every round (was round 0 only).
- C++: a flag bit cannot bind to a flag byte read inside a `flags` member or a flag-bit child; the outer byte binds when one exists.
- C#: a typed member whose collection or element type cannot hold its field fails at `new Scheme<T>`; a non-null typed nested row with all-null members counts as present under `Flags` and pack fails naming the first missing member; `u2` slots, `bits` and `packed` items refuse fractions, out-of-range values, bool, string, char, enum, object and null; dictionary `Pack` of group elements that `Read` returned works; an int for `Bytes` or `Sized` is an `ArgumentException`; a `Flags` list or dict element works.

## Commit

`[AZ-2126] [AZ-2304] ... Loop 18 wave 1` (see git log). Body: one line + `Loop: 18`.

## Next Batch: wave 2 (AZ-2126 hostile vector `eq_bool_false`, AZ-2194), then wave 3 (AZ-2120 and the AZ-2128 angle)
