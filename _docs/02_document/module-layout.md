# Module Layout

**Language**: mixed
**Layout Convention**: custom
**Root**: ./
**Last Updated**: 2026-10-13

## Layout Rules

1. Each language package owns one top-level directory.
2. The packages do not import each other. There is no `shared/` code package.
3. The golden fixture is data, owned by the bootstrap task. Every package reads it. None of them import it as a library.
4. Public API is the file or headers named below. Other files in that directory are internal.
5. Test paths are in the table below. Java tests live in `java/src/test/`.

## ADR-driven exceptions to the conventional layout

A single `src/`, `crates/`, or `packages/` tree would put eight languages in one convention. ADR 002 publishes six registries from one tag, and ADR 003 publishes C++ as its own vcpkg port. Each language therefore keeps that language's files inside its own root.

> See ADR 002_publish-from-version-tag, ADR 003_cpp-vcpkg-git-registry.

## Per-Component Mapping

### Component: csharp

- **Epic**: AZ-1859
- **Directory**: `csharp/`
- **Public API**:
  - `csharp/Packbin.cs`
- **Internal (do NOT import from other components)**:
  - `csharp/**` except `csharp/Packbin.cs`
  - Other public types, by file: `csharp/Field.cs` (`Field`), `csharp/Fields.cs` (`Fields<T>`), `csharp/PackSession.cs` (`PackSession`), `csharp/Bound.cs` (`Bound<T>`; it was in `ObjectValues.cs`, deleted in loop 17). The public surface is the same before and after loop 17 (reflection dumps of both targets are identical)
  - Targets (commit `68ca4f8`): `csharp/Packbin.csproj` multi-targets `netstandard2.0;net10.0`; `csharp/Compat.cs` holds the .NET 10 calls the `netstandard2.0` build lacks; the tests run against both (`dotnet test -p:PackbinTarget=netstandard2.0`, `csharp/tests/TargetParityTests.cs`); the session pad is `csharp/SessionPad.cs`
  - Typed rows (loop 17, AZ-2092): `csharp/RowBinding.cs` (reads a row into a `RowValues` and applies unpacked values back; nested rows and list and dict elements), `csharp/FieldBinding.cs` (what a field needs to read and write its member: the nested row type and constructor, `CollectionShape`, `Creator`), `csharp/FieldAccess.cs` (`MemberAccess`: getter and setter compiled once per accessor when the field is built)
  - Construction checks: `csharp/FlagScopes.cs` (`Bind` binds and numbers the split flag bits, a nested row is a scope of its own; it replaced `Validate`, AZ-2135), `csharp/FlagGroup.cs` (the bits of one read of a flag byte, at most eight), `csharp/RoundScopes.cs` (a `repeat` or `times` inside a round, loop 13); the reference scope, count-kind, `Eq` value, row-type and constructor checks are `SchemeOrder` in `csharp/SchemeOrder.cs` (moved out of `Packbin.cs` in loop 19, AZ-2342)
  - Walkers: `csharp/Walker*.cs`: `Walker.cs` (dispatch, scalars), `Walker.Flags.cs` (`PackFlags`, `PackFlagByte`, `PackFlagBit`, `RequireNoDroppedBody`, unpack of flags; loop 19), `Walker.Equality.cs` (`ConditionHolds`, `ValuesEqual`; loop 19), `Walker.Scalars.cs`, `Walker.Counted.cs` (`sized`, `u2`, `bits`, `packed`, `times`, `utf8`, `RequireCount`), `Walker.Collections.cs` (`list` and `dict` pack and unpack, group and flags element rows; loop 18, split out of `Walker.Counted.cs`), `Walker.Presence.cs` (flag group presence), `Walker.Rounds.cs` (round pack and aligned unpack, loop 13; lone values, loop 17), `Walker.Elements.cs` (the value one list or dict element read, AZ-2119, loop 17) and `Walker.Numbers.cs` (strict dictionary-row numbers, AZ-2191, loop 17); per-call state in `csharp/Scope.cs`, which also holds the round budget (`RoundBudget`, loop 15)
  - Tests: `csharp/tests/RoundLimitTests.cs` (round limits, AZ-2216); the hostile `limit` cases are replayed in `csharp/tests/HostileVectorTests.cs`. Loop 17: `TypedBindingTests.cs` and `TypedParityTests.cs` (typed rows; the first pins the README C# example verbatim), `NestedRowFlagByteTests.cs`, `SplitBitOrderTests.cs` (AZ-2135), `FlagGroupCopyTests.cs` (AZ-2180), `FlagGroupPresenceTests.cs` and `U2PresenceTests.cs` (AZ-2128), `CountKindTests.cs` and `CountOverflowTests.cs` (AZ-2181), `LoneRoundValueTests.cs` (AZ-2182), `GroupElementTests.cs` (AZ-2119), `StrictNumberTests.cs` (AZ-2191), `HostileSessionTests.cs` (AZ-2114), `SplitFormReferenceTests.cs` (AZ-2115), `FlagScopeContainerTests.cs` (AZ-2121), `SessionPrivates.cs` (the helper that reads the private session fields, used by `HostileSessionTests.cs` and `TopRangeAndSessionTests.cs`). Loop 18: `EqBoolTrueOnlyTests.cs` and `FloatConditionValueTests.cs` (AZ-2126), `CollectionMemberTests.cs` and `CollectionElementKindTests.cs` (AZ-2305), `EmptyNestedRowTests.cs` (AZ-2306), `FlagsElementTests.cs` and `DictionaryElementTypedRowTests.cs` (AZ-2307), `LoneDictRoundTests.cs` (AZ-2308), `StrictSlotTests.cs` (AZ-2309), `DictRepackTests.cs` (AZ-2310), `FlagsWhenMemberTests.cs` and `FlagsRoundMemberTests.cs` (AZ-2120), `HostilePackVectorTests.cs` (AZ-2194). Loop 19: `PackRoundCapTests.cs` (AZ-2329), `SplitFormDroppedBodyTests.cs` (AZ-2331), `GroupElementMembersOnlyTests.cs` (AZ-2337), `EqValueConstructionTests.cs` (AZ-2338), `TimesZeroWithValuesTests.cs` (AZ-2335) and rows added to `LoneRoundValueTests.cs` (AZ-2332)
  - Loop 20: new `csharp/PackOut.cs` (the pack output buffer with the byte budget); `Packbin.cs` (`MaxBytes`, `WithLimits` third parameter), `Walker.Rounds.cs` (`RequireSlots`, `RequireRepeatWithinLimit`), `Walker.Flags.cs` (`RequireNoValuesForSkippedCount`, `FirstName`), `Scope.cs` (`RoundBudget` charges pack slots), `FieldBinding.cs` (`CollectionShape.HoldsRounds`), `RowBinding.cs` (`To` with `out unfit`), `SchemeOrder.cs` (`RequireCollection` in a round, whole-float `Eq`); tests `PackOutputBudgetTests.cs`, `PackSlotBudgetTests.cs`, `PackRepeatRoundCapTests.cs`, `PackOutCapTests.cs`, `BudgetSupport.cs` (AZ-2354, AZ-2355), `TypedRoundUnpackTests.cs`, `RoundCollectionMemberTests.cs` (AZ-2366), `FlagsSkippedCountTests.cs` (AZ-2360), `EnumSlotValuesTests.cs` (AZ-2359), `LayoutCountedTests.cs` split out of `LayoutTests.cs` (AZ-2365), rows in `StrictSlotTests.cs`, `EqValueConstructionTests.cs`, `FloatConditionValueTests.cs` (AZ-2358) and `HostilePackVectorTests.cs` (AZ-2367)
  - Loop 21: new `csharp/RowRounds.cs` (typed rounds of rows), `csharp/Walker.RowRounds.cs`, `csharp/Walker.ShortLists.cs` and `csharp/Walker.StrandedCounts.cs`; `RoundScopes.cs` (`CheckBodies`), `SchemeOrder.cs` (`RoundRow`), `FieldBinding.cs`, `RowBinding.cs`, `Field.cs`, `Fields.cs`, `Packbin.cs` (`WithLimits(int, long)`), `Walker.Numbers.cs` and `Walker.Scalars.cs` (exact integer types, floats refused for integer fields). New tests: `RoundSlotWidthTests.cs`, `RoundSlotWidthTypedTests.cs`, `ShortOptionalListTests.cs`, `SplitTimesClearBitTests.cs`, `CountBehindClearWhenTests.cs`, `EmptyRoundBodyTests.cs`, `ExactIntegerTypeTests.cs`, `RowRoundTests.cs`, `RowRoundMemberTests.cs`, `CountTextAndLimitsTests.cs`; the hostile loaders gain the 15 new cases (AZ-2373, AZ-2381 to AZ-2394)
  - Loop 22: no new source file; `FieldBinding.cs` (`CollectionShape.IsReal`), `SchemeOrder.cs` (the integer-list element check), `Walker.StrandedCounts.cs` (`IsPositive(count, bias)`, the no-value count text), `Packbin.cs` (`DefaultMaxSlots` 1 048 576). New tests: `IntegerListFloatMemberTests.cs`; `CountBehindClearWhenTests.cs`, `PackSlotBudgetTests.cs`, `RoundLimitTests.cs`, `HostilePackVectorTests.cs` and `HostileVectorTests.cs` changed (AZ-2410, AZ-2411, AZ-2415, AZ-2417, AZ-2418)
  - Loop 23: no source change. New test: `tests/NoValueCountNestedTests.cs` (AZ-2436, the AZ-2437 parity row).
  - Loop 25 (AZ-2473, U26 A): `Walker.cs` (`PackGroup`, `UnpackGroup`), `Walker.Presence.cs` (`ScopeOf`), `Walker.Collections.cs` (`ElementValues`) and `Walker.Elements.cs` (`ElementValue`) read and return a nested-row group through the nested dictionary under its name; new tests `tests/DictNestedRowGroupTests.cs` and `tests/Loop25ProbeD1D7Tests.cs` (AZ-2478, AZ-2476).
- **Owns (exclusive write during implementation)**: `csharp/**`
- **Imports from**: none
- **Consumed by**: the caller's server

> See ADR 001_runtime-primitives-no-generator.

### Component: typescript

- **Epic**: AZ-1860
- **Directory**: `typescript/`
- **Public API**:
  - `typescript/src/index.ts`
- **Internal (do NOT import from other components)**:
  - `typescript/src/**` except `typescript/src/index.ts`
  - Construction checks: `typescript/src/flag-scope.ts`, `typescript/src/member-names.ts` (name collisions) and `typescript/src/ref-scope.ts` (reference binder), the last two new in loop 13; the nested-round refusal is `validateRoundNesting` in `typescript/src/rounds.ts`; `typescript/src/element-kinds.ts` (`validateElementKinds`, run last by the `Scheme` constructor, AZ-2236) refuses a `list` or `dict` whose element is an anchored `group`
  - Walkers: `typescript/src/walker.ts` (unpack), `typescript/src/pack-fields.ts` (pack; since loop 16 it keeps a map of what pack wrote in each scope for `when` and counts), `typescript/src/rounds.ts` (round names, count, slice, aligned lists and `refuseLongLists`, loop 13), `typescript/src/flag-bits.ts` (which flag bits pack sets: `collectFlagBits`, `bitOn`, `flagValueFor`; new in loop 16; `droppedBody` since loop 19); construction also binds and numbers the split flag bits in `typescript/src/flag-scope.ts` (`bindFlagBits`, AZ-2135); the unpack round counters live on `ViewCursor` in `typescript/src/kinds.ts` and `refuseRound` in `walker.ts` checks them (loop 15)
  - Tests: `typescript/tests/round-limits.test.ts` (round limits, AZ-2217); the hostile `limit` cases are replayed in `typescript/tests/hostile.test.ts`. Loop 16: `u64-count.test.ts` (AZ-2112), `list-group-elements.test.ts` (AZ-2102), `times-longer-list.test.ts` (AZ-2185), `flags-under-split-bit.test.ts` (AZ-2183), `dict-keys-not-flattened.test.ts` (AZ-2184), `duplicate-names.test.ts` (AZ-2188), `when-on-written-values.test.ts` (AZ-2197), `flag-group-presence.test.ts` (AZ-2128), `split-bits-field-order.test.ts` (AZ-2135), `split-form-reference.test.ts` (AZ-2115), `list-element-kinds.test.ts` (AZ-2236), with the seeded generator in `tests/support/random.ts`; `session.test.ts` holds the AZ-2243 `PackSession.load` tests (the `isUint8Array` brand is in `typescript/src/index.ts`)
  - Package build (loop 16, AZ-2103): `typescript/tsconfig.build.json` and the `build` script of `typescript/package.json` compile `src` to `dist` (`typescript/dist/` is gitignored; the npm package ships `dist/` only); the tests and the CI drivers keep running from `src`
  - Loop 18: `typescript/src/written.ts` (what pack wrote in a scope: `seen`, `writtenCount`, `borrowedCount`, moved out of `pack-fields.ts`); tests `typescript/tests/eq-source-kinds.test.ts` (AZ-2126), `lone-dict-in-round.test.ts` and `dict-non-plain-object.test.ts` (AZ-2308 and the `Map` refusal), `flags-when-member.test.ts` and `flags-times-repeat-member.test.ts` (AZ-2120), with the helpers `tests/support/hostile-pack.ts` (AZ-2194) and `tests/support/member-cases.ts`
  - Loop 19: `pack-fields.ts` carries a `PackState` (`flagBytes`, `maxRounds`); `rounds.ts` holds `refuseLoneBuffers` and `refuseRoundsOverLimit`; `ref-scope.ts` checks the `eq` value against the range of an integer source; tests `pack-round-count-cap.test.ts` (AZ-2329), `split-form-loud-pack.test.ts` (AZ-2331), `lone-bytes-in-round.test.ts` (AZ-2332), `times-count-zero-with-values.test.ts` (AZ-2335), `eq-value-checked.test.ts` (AZ-2338)
  - Loop 20: new `typescript/src/pack-out.ts` (`PackOut`); `index.ts` (`maxBytes`, `Scheme.DefaultMaxBytes`), `pack-fields.ts` (`PackState.maxSlots`, `slots`; slots charged per round) and `rounds.ts` (`refuseRepeatOverLimit`); tests `pack-output-budget.test.ts`, `pack-repeat-round-cap.test.ts`, `loop20-parity-pins.test.ts`, the helper `tests/support/lone-utf8-budget.ts` (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2363), a `PACK_REFUSAL` table in `hostile.test.ts` and new cases in `tests/support/hostile-pack.ts` (AZ-2367)
  - Loop 21: no new source file; `rounds.ts` (`validateRoundBodies`, `refuseShortOptional`, `RoundShape.optionalNames`, `sliceRound` and `overlay` without the scope copy), `flag-bits.ts` (`refuseUnwrittenCount`), `index.ts` and `pack-fields.ts` call them. New tests: `round-slot-width.test.ts`, `empty-round-body.test.ts`, `repeat-short-optional.test.ts`, `loop21-parity-probes.test.ts`, `round-scope-cost.test.ts`; the hostile loader (`support/hostile-pack.ts`, `support/hostile-cases.ts`) replays the 15 new cases
  - Loop 22: no new source file; `flag-bits.ts` (`refuseUnwrittenCount` for `bits`, `packed`, `sized`), `index.ts` (`DefaultMaxSlots` 1 048 576). New tests: `loop22-novalue-count.test.ts`, `loop22-max-slots.test.ts`, `support/unpack-memory.ts` (the memory A/B script); `hostile.test.ts`, `support/hostile-pack.ts`, `support/hostile-cases.ts` changed (AZ-2410, AZ-2415, AZ-2417, AZ-2418)
  - Loop 23: no new source file; `flag-bits.ts` (`refuseUnwrittenCount` refuses a bigint above `MAX_SAFE`), `kinds.ts` (`MAX_SAFE` exported). New tests: `loop23-bigint-count.test.ts`, `loop23-novalue-nested.test.ts`.
- **Owns (exclusive write during implementation)**: `typescript/**`
- **Imports from**: none
- **Consumed by**: Vue, React, and Node

> See ADR 001_runtime-primitives-no-generator.

### Component: python

- **Epic**: AZ-1861
- **Directory**: `python/`
- **Public API**:
  - `python/src/packbin/__init__.py`
- **Internal (do NOT import from other components)**:
  - `python/src/packbin/**` except `python/src/packbin/__init__.py`
  - Construction checks: `python/src/packbin/_validate.py` (`_validate_order` for ids, references and bool placement, `_validate_round_nesting`; new in loop 16, `_validate_order` moved there from `_nodes.py`); `python/src/packbin/_flag_scope.py` (`_bind_flag_bits`: the split flag bit scope check and the numbering by scheme, AZ-2230; it replaced `_validate_flag_bits` and `_check_flag_scopes`); `_validate_names` and `_validate_element_accessors` in `_validate.py` (AZ-2245, AZ-2249: a member name declared twice, an attribute accessor in an element group; `Scheme.__init__` runs them last, over the accessor `access` mark that `_nodes.py` sets); `python/src/packbin/_session.py` (`_exact_bytes`, the one check of a seed or nonce for `load`, `start` and `join`, AZ-2244)
  - Walkers: `python/src/packbin/_pack.py` (pack), `python/src/packbin/_unpack.py` (unpack, with the per-call `_Budget` of the round limits, loop 16); `python/src/packbin/_scheme.py` holds `Scheme` (`with_limits`, `max_rounds`, `max_slots`) and `BinaryPacker`; the field builders and nodes are `python/src/packbin/_nodes.py`
  - Tests: `python/tests/test_reference_scope.py` (AZ-2113), `test_star_import.py` (AZ-2104), `test_times_longer_list.py` (AZ-2186), `test_float_pack_strict.py` (AZ-2192), `test_split_form.py` (AZ-2100), `test_round_lists.py` (AZ-2134), `test_flag_group_presence.py` (AZ-2128), `test_split_bits_field_order.py` (AZ-2230), `test_session.py` (AZ-2104, AZ-2231, AZ-2244), `test_duplicate_names.py` (AZ-2245), `test_times_short_list.py` (AZ-2248), `test_element_accessors.py` (AZ-2249), `test_round_limits.py` (round and slot limits); the hostile `limit` cases are replayed in `test_hostile_vectors.py` with the schemes of `hostile_support.py`
  - Loop 18 tests: `python/tests/test_when_count_sources.py` (AZ-2126), `test_lone_dict_in_round.py` (AZ-2308), `test_flags_when_member.py` and `test_flags_round_member.py` (AZ-2120), `test_scheme_error_values.py` (error texts show a type name, not the `repr`, for a non-scalar value)
  - Loop 19: `_pack.py` takes the scheme's `max_rounds` (`BinaryPacker.pack` in `_scheme.py` passes it), `_unpack.py` starts each round with an empty scope, `_validate.py` checks the `eq` value (`_require_eq_value`); tests `python/tests/test_round_fresh_scope.py` (AZ-2330), `test_pack_round_count_cap.py` (AZ-2329), `test_split_form_pack_fails_loudly.py` (AZ-2331), `test_lone_bytes_in_round_refused.py` (AZ-2332), `test_times_count_zero_with_values.py` (AZ-2335), `test_eq_value_checked.py` (AZ-2338)
  - Loop 20: new `python/src/packbin/_pack_limits.py` (`_PackBudget`, `round_member`) and `_pack_rounds.py` (round lists, `_refuse_repeat_over_limit`); `_pack.py` and `_scheme.py` (`max_bytes`, `DEFAULT_MAX_BYTES`); tests `test_pack_output_budget.py`, `test_pack_repeat_round_cap.py`, `test_loop20_parity_pins.py` (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2362), rows in `test_split_form_pack_fails_loudly.py` and `test_pack_round_count_cap.py`, and the hostile pack cases in `hostile_support.py` (AZ-2367)
  - Loop 21: no new source file; `_nodes.py` (`_round_width`, `_finish_round`), `_unpack.py` (no surcharge), `_pack.py` (`_refuse_unwritten_count`), `_pack_rounds.py` (`_refuse_short_optional`), `_validate.py` (`_validate_round_bodies`), `_flag_scope.py` and `_scheme.py`. New tests: `test_round_slot_width.py`, `test_empty_round_body.py`, `test_repeat_short_optional.py`, `test_loop21_parity_probes.py`, `hostile_refusals.py`, `hostile_loop21_support.py`
  - Loop 22: no new source file; `_pack.py` (`_unwritten_sources`, `_refuse_unwritten_count` for `sized`/`bits`/`packed`; the equal-length check removed), `_nodes.py` and `_validate.py` (`count_source` on the three kinds), `_flag_scope.py` (`_bind` copies a counted leaf), `_unpack.py` (`DEFAULT_MAX_SLOTS` 1 048 576). New tests: `test_loop22_parity.py`, `test_shared_count_node.py`, `hostile_loop22_support.py`; `test_hostile_vectors.py`, `hostile_refusals.py`, `test_repeat_short_optional.py`, `test_round_lists.py` changed (AZ-2410, AZ-2413, AZ-2415, AZ-2417, AZ-2418)
  - Loop 23: no new source file; `_pack_rounds.py` (`_RoundValues`, `unwritten_count`), `_pack.py` (`count_of` into `_refuse_unwritten_count`). New tests: `test_no_value_count_nested.py`, `test_raised_max_slots.py`.
  - Loop 25 (AZ-2474, Low-1 A): `src/packbin/_pack.py` and `_pack_rounds.py` (`_borrowed` takes the count id) raise `ValueError` with `<label>: count <id> was not written`; new tests `tests/test_az2474_value_error_text.py`, `tests/test_loop25_probe_d1_d7.py` (AZ-2478, AZ-2476).
- **Owns (exclusive write during implementation)**: `python/**`
- **Imports from**: none
- **Consumed by**: tools and scripts

> See ADR 001_runtime-primitives-no-generator.

### Component: rust

- **Epic**: AZ-1862
- **Directory**: `rust/`
- **Public API**:
  - `rust/src/lib.rs`
- **Internal (do NOT import from other components)**:
  - `rust/src/**` except `rust/src/lib.rs`
  - Construction checks (`MapScheme::new`): `rust/src/field/order.rs`, `field/shape.rs`, `field/integrity.rs` (`when` source and element kinds, loop 13; the scope of every `when` and count, by name and by id, loop 16), `field/names.rs` (`check_names`: a data name declared twice in one scope, AZ-2247)
  - Typed layer: `rust/src/scheme/mod.rs` and `scheme/bound.rs`; `scheme/times.rs` (the typed `times` over a `Vec<E>`, loop 13) is reached through `SchemeItem::times`
  - Walkers: `rust/src/walk/pack.rs`, `walk/unpack.rs`, `walk/element.rs`, and `walk/times.rs` (round lists, the list/rounds agreement check, loop 13, `check_aligned` for a member below `flags` or `when`, loop 16, and `check_longer`, AZ-2237), `walk/flag_bits.rs` (`collect_flag_bits`, `group_on`, `any_member_on`, `member_on`: which flag bits pack sets; moved out of `walk/pack.rs` in AZ-2237; `pack.rs` keeps what pack wrote in each scope in `Written` and `RoundLists`); `walk/cursor.rs` holds the per-call `Cursor` with the round limits (loop 15; moved out of `walk/unpack.rs` in loop 19, AZ-2342, with `read_int`, `read_float` and `packed_layout`); `field/leaf.rs` holds the leaf field constructors (moved out of `field/mod.rs` in loop 19); `session/mod.rs` holds `PackSession` and `SessionPackError` (loop 16)
  - Tests: `rust/tests/round_limits_tests.rs` (round limits, AZ-2219); the hostile `limit` cases are replayed in `rust/src/hostile_tests.rs`. Loop 16: `rust/src/name_scope_tests.rs` (AZ-2117), `rust/src/flag_group_tests.rs` (AZ-2128), `rust/src/session_hostile_tests.rs` (AZ-2114), and the session pack tests in `rust/tests/session_tests.rs` (AZ-2105), the map `times` under `flags` tests in `rust/src/times_tests.rs` (AZ-2189) the checked-count test in `rust/src/borrowed_count_tests.rs` (AZ-2118), and the pack-from-written-values tests (AZ-2237): `rust/src/when_written_tests.rs`, `when_kept_tests.rs`, `when_names_tests.rs` and `times_longer_tests.rs`, and the member-name tests (AZ-2247) `rust/src/duplicate_names_tests.rs` and `duplicate_names_kept_tests.rs`
  - Loop 18: `rust/src/walk/written.rs` (`Written`, what pack wrote in a scope, moved out of `walk/pack.rs`); tests `rust/src/eq_bool_true_tests.rs` (AZ-2126), `times_lone_value_tests.rs` (AZ-2308, AZ-2311), `flags_when_member_tests.rs`, `flags_round_member_tests.rs` and `flags_zero_rounds_tests.rs` (AZ-2120), `rust/tests/flags_member_typed_tests.rs` (the typed `Scheme<T>` forms)
  - Loop 19: `check_round_cap` in `walk/times.rs`, `check_split_bit` in `walk/flag_bits.rs`, `shape_one` per `flags` member in `field/shape.rs` (AZ-2333), the `eq` range in `field/integrity.rs`; tests `rust/src/pack_round_cap_tests.rs` (AZ-2329), `split_form_loud_tests.rs` (AZ-2331), `flags_member_scope_tests.rs` (AZ-2333), `lone_bytes_in_round_tests.rs` (AZ-2332), `times_count_zero_tests.rs` (AZ-2335), `eq_range_tests.rs` (AZ-2338)
  - Loop 20: new `rust/src/walk/pack_out.rs` (the pack output buffer, the slot charge) and `rust/src/scheme/bound_collections.rs` (split out of `scheme/bound.rs`, AZ-2365); `field/map_scheme.rs` and `scheme/mod.rs` (`with_max_bytes`, `max_bytes`, `DEFAULT_MAX_BYTES`), `walk/flag_bits.rs` (`Form`), `walk/times.rs` (the `repeat` cap); tests `rust/src/pack_output_budget_tests.rs`, `pack_repeat_cap_tests.rs`, `loop20_parity_pins_tests.rs` and a `PACK_NOT_RUN` table in `hostile_tests.rs` (AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2367)
  - Loop 21: new `rust/src/field/round_body.rs` (`check_round_bodies`); `field/map_scheme.rs` (`round_width` replaces `count_fields` for slots), `field/mod.rs`, `walk/flag_bits.rs` (`early_on`, `refuse_unwritten_count`), `walk/pack.rs`. New tests: `rust/tests/round_slot_width_tests.rs`, `empty_round_body_tests.rs`, `late_when_in_bit_body_tests.rs`, `loop21_parity_probes_tests.rs`, `count_behind_clear_when_tests.rs`; `src/hostile_tests.rs` is split into `hostile_tests/pack_cases.rs` and `hostile_tests/refusals.rs`
  - Loop 22: no new source file; `walk/flag_bits.rs` (`refuse_count`), `walk/times.rs` (`check_repeat_lists`, `slice_times` per-round loop, `Below` names), `walk/pack.rs`, `field/map_scheme.rs` (`DEFAULT_MAX_SLOTS` 1 048 576). New tests: `rust/src/repeat_lists_without_groups_tests.rs` (declared in `lib.rs`), `rust/tests/loop22_parity_tests.rs`; `hostile_tests.rs`, `hostile_tests/pack_cases.rs`, `hostile_tests/refusals.rs`, `times_tests.rs`, `times_longer_tests.rs` changed (AZ-2410, AZ-2412, AZ-2414, AZ-2415, AZ-2417, AZ-2418)
  - Loop 23: no new source file; `walk/times.rs` (`lists_agree`, `check_repeat_lists`, `collect_below`, `times_keys`, `declares`), `walk/pack.rs`, `walk/flag_bits.rs` (`repeat_on`), `walk/mod.rs` (rustdoc). New tests: `tests/repeat_dropped_values_tests.rs`, `tests/no_value_count_nested_tests.rs`, `tests/raised_slot_limit_tests.rs`.
  - Loop 25: no source change. New test `tests/loop25_probe_d1_d7_tests.rs` (AZ-2478, AZ-2476).
  - Loop 51 (AZ-2752, AZ-2753): `rust/src/nostd/` is `scheme.rs` (kinds, `Field`, builders, `Scheme`), `check.rs` (`validate`), `table.rs` (table walking, references), `present.rs` (presence, sources, clear), `pack.rs`, `unpack.rs`, `row.rs`, `io.rs`, `error.rs`, `walk.rs` (entry points); tests `rust/tests/nostd_bits_when_tests.rs`, `nostd_rounds_tests.rs`, `nostd_support/{tree,random}.rs`.
  - Loop 50 (planned, epic AZ-2750): new `rust/src/nostd/**` (the `no_std`, heap-free core: errors, `Reader`/`Writer`, `Row`, plain-data schemes, one file per field-kind group, `text`, `ecc`, `session` behind Cargo features), `rust/Cargo.toml` features, `rust/embedded/**` (device image recipe, size and link checks), the CI job for it; tests `rust/tests/nostd_*`. Shared pure code (`ecc.rs` tables, `session/sha256.rs`, `hkdf.rs`, `pad.rs`, `walk/text_tables.rs`) stays where it is and is used by both walkers.
- **Owns (exclusive write during implementation)**: `rust/**`
- **Imports from**: none
- **Consumed by**: a native node

> See ADR 001_runtime-primitives-no-generator.

### Component: cpp

- **Epic**: AZ-1863
- **Directory**: `cpp/`
- **Public API**: the headers in `cpp/include/packbin/`
  - `codec.hpp` (`scheme`, `pack`, `unpack`, `on`, `validate`), `session.hpp` (`PackSession`, `RandomFn`), `os_random.hpp` (host random source)
  - `core.hpp` (`Result`, `Error`, `Reader`, `Writer`), `fields.hpp`, `fields_grouped.hpp`, `fields_counted.hpp` (field builders), `order.hpp` (field-order rules), `table.hpp` (`Field`, `Opt`, `View`, `Text`, `Blob`, `Array`, `Entry`)
  - `packbin.hpp` includes `codec.hpp`, `os_random.hpp` and `session.hpp`; `cpp/arduino/packbin.h` includes `codec.hpp` and `session.hpp`
- **Internal (do NOT import from other components)**:
  - `cpp/src/core/*.cpp` and `cpp/src/core/values.hpp` (the walker: `pack.cpp`, `unpack.cpp`, `values.cpp`, `session.cpp`)
  - `cpp/src/os_random.cpp` (host only; firmware does not compile it)
  - Split flag bits (loop 16, AZ-2135): `find_flag_byte` and `bit_position` in `cpp/include/packbin/order.hpp` bind a bit to a flag byte of its container read before it and outside a closed `when`; `unpack_when` in `cpp/src/core/unpack.cpp` restores the flag byte values when a taken `when` ends; tests in `cpp/tests/core/grouped_tests.cpp`
- **Tests**: `cpp/tests/core/*_tests.cpp` (the vector suites also run on firmware), `cpp/tests/core/hostile_host_tests.cpp` (runs `fixtures/hostile/cases.txt` on the host), `cpp/tests/compile-fail/` (cases that must not compile)
- **Embedded and packaging**:
  - `cpp/embedded/` — the target driver `run.sh`, the arm and ESP stages, the Dockerfile for the `cpp-embedded` image; `lib.sh` holds `run_target` (which always returns 0: a target is FAIL on a non-zero exit of its function or on the marker `<id>.failed` that `fail` leaves, and `run.sh` exits 1 when any target failed; loop 16, AZ-2099) and `cpp/embedded/lib.test.sh` tests it (31 checks, run by the `scaffold` job; one scans `cpp/embedded/*.sh` for `find | head`, AZ-2238); since loop 31 (AZ-2607) `run.sh` lists every target once in `embedded_table` (stage, part, id, name, function), has the forms `host [arm | esp [core|packages|all]]`, `list <stage> [part]` and the in-container `PACKBIN_ESP_PART`, and in host mode on GitHub Actions writes one timing notice; `cpp/embedded/run-parts.test.sh` (73 checks against a fake `docker`, 26 mutants, run by the `scaffold` job and the Mac `scaffold` stage) holds each target to one part
  - `cpp/examples/` — the Pico (PlatformIO), Arduino-ESP32 and ESP-IDF examples
  - `cpp/arduino/` — `library.properties` and `packbin.h` for the Arduino layout
  - `cpp/library.json` (PlatformIO), `cpp/idf_component.yml` and `cpp/CMakeLists.txt` (ESP-IDF component and plain CMake library; since loop 16 the host branch also installs and exports `packbin::packbin`, the target the vcpkg port builds, AZ-2098, and writes the version file with `SameMinorVersion` below 1.0, AZ-2232)
  - Loop 18 tests (host only): `cpp/tests/core/flag_scope_host_tests.cpp` (AZ-2304), `source_kinds_host_tests.cpp` (AZ-2126), `flags_when_member_host_tests.cpp`, `flags_times_repeat_member_host_tests.cpp` and `member_cases.hpp` (AZ-2120), `hostile_pack_cases.hpp` (AZ-2194); compile-fail cases `flag_byte_in_flags_member.cpp`, `flag_byte_in_flag_bit_child.cpp` and `when_eq_bool_false.cpp`
  - Loop 19: `Field::late` in `table.hpp`, `mark_late`, `find_ref` (empty group) and `eq_fits` in `order.hpp`, `pack_flag_byte` in `pack.cpp`, `times_present` and `read_int` in `values.cpp`; host tests `split_form_loud_host_tests.cpp` and `late_source_host_tests.cpp` (AZ-2331), `times_count_zero_host_tests.cpp` (AZ-2335), `eq_value_checked_host_tests.cpp` (AZ-2338), rows added to `source_kinds_host_tests.cpp` (AZ-2334) and `flags_when_member_host_tests.cpp` (AZ-2340); compile-fail case `when_eq_out_of_range.cpp`
  - Loop 20: no new file in `cpp/src`; `mark_held` and the `mark_late` chain in `order.hpp`, the `Field::bit` and `Field::late` comments in `table.hpp`, `count_skipped`, `under_clear_when` and `pack_flag_byte` in `pack.cpp`; new host test `held_count_nested_late_host_tests.cpp`, rows in `split_form_loud_host_tests.cpp`, `late_source_host_tests.cpp`, `times_count_zero_host_tests.cpp` and `hostile_pack_cases.hpp` (AZ-2356, AZ-2357, AZ-2360, AZ-2364, AZ-2367). The pack budget does not exist here (caller buffer, fixed arrays)
  - Loop 21: no new file in `cpp/src`; `order.hpp` (`empty_round` in `check_shape`), `table.hpp` (`flag::Late` comments), `fields_counted.hpp`, `src/core/pack.cpp` (`pack_flag_byte` packs a late body when another child sets the bit; `under_clear_when` removed), `src/core/values.cpp` and `values.hpp` (`present(..., skip)`). New tests: `tests/core/hostile_pack_loop21.hpp`; `late_source_host_tests.cpp`, `container_tests.cpp`, `hostile_host_tests.cpp` changed. Arm stage: 8152 of 8192 B flash, 456 of 512 B stack
  - Loop 22: no new file in `cpp/src`; `include/packbin/order.hpp` (`has_member`, used by `empty_round` in `check_shape`; the header, not `src/core`). New tests: `tests/core/hostile_rule_check.hpp` and `hostile_rule_check_host_tests.cpp` (split out of `hostile_host_tests.cpp`, added to `HOST_TESTS` in `cpp/Makefile`); `times_count_zero_host_tests.cpp`, `held_count_nested_late_host_tests.cpp`, `hostile_pack_loop21.hpp` changed. Arm stage: 8152 of 8192 B flash, 456 of 512 B stack (AZ-2416, AZ-2417, AZ-2418)
  - Loop 23: no new file in `cpp/src`; `include/packbin/fields.hpp` (`when()` marks an `eq` id outside 0..32 767 Invalid). New tests: `tests/core/empty_body_rule_host_tests.cpp` (U19, G2; the AZ-2416 tests moved here from `times_count_zero_host_tests.cpp`), `packed_bias_novalue_host_tests.cpp` (U20), `novalue_nested_host_tests.cpp` (AZ-2436); `hostile_pack_loop21.hpp` skip reasons reworded (G4).
  - Loop 25 (AZ-2472, U25 A): `include/packbin/table.hpp` (`leaf` marks an id outside 0 to 32,767 invalid; -1 stays) and `include/packbin/fields_counted.hpp` (`counted_leaf`, the same for a count id; -1 is the never-written sentinel); flash and stack unchanged (8152 of 8192 B, 456 of 512 B). New host tests `tests/core/builder_id_range_host_tests.cpp` and `tests/core/loop25_probe_d1_d7_host_tests.cpp`, registered in `Makefile` and `tests/core/main.cpp`.
- **Owns (exclusive write during implementation)**: `cpp/**`
- **Imports from**: none
- **Consumed by**: a C++ program or firmware

> See ADR 001_runtime-primitives-no-generator, ADR 003_cpp-vcpkg-git-registry.

### Component: java

- **Epic**: AZ-1864
- **Directory**: `java/`
- **Public API**:
  - `java/src/main/java/packbin/Packbin.java`
- **Internal (do NOT import from other components)**:
  - `java/src/**` except `java/src/main/java/packbin/Packbin.java`
  - API-level check (loop 14, AZ-2094): `java/api-check.sh`, `java/tools/ApiCheck.java`, `java/tools/Fetch.java`, run from `java/test.sh`; tool cache `java/out/api-tools` (gitignored)
  - Round limits (loop 15, AZ-2218): `Cursor.java` (read position and round budget of one unpack call, replaces the `int[] offset` of every unpack method), `Scheme.java` (`withLimits`), `Rounds.java`; tests `java/src/test/java/packbin/RoundLimitsTest.java` (run from `PackbinTest`), the hostile `limit` cases in `HostileVectorTest.java`
  - Loop 16 tests, all run from `PackbinTest`: `NestedRoundTest` (AZ-2127), `TimesLongerTest` (AZ-2187), `PackStrictTest` (AZ-2190), `TypedNestedRowTest` (AZ-2101), `FlagPresenceTest` (AZ-2128), `HostileSessionTest` (AZ-2114), `FlagScopeContainerTest` (AZ-2121), `SplitBitOrderTest` (AZ-2135, AZ-2233), `MissingNestedValueTest` (AZ-2234), `TypedElementScopeTest` (AZ-2235), `DuplicateNamesTest` (AZ-2246); `TypedNestedRowTest` also holds the AZ-2235 element-group cases. The split flag bits are bound and numbered in `SchemeOrder.bindFlagBits` (the `Scheme` constructor calls it after `SchemeOrder.validate`); `MemberNames.java` (AZ-2246) is the member-name check, run last by the constructor, and `Access.set(String)` returns the package-private `Access.KeySetter` that holds the key
  - Loop 18 tests: `java/src/test/java/packbin/EqBoolTrueOnlyTest.java` (AZ-2126), `LoneDictRoundTest.java` (AZ-2308), `FlagsWhenMemberTest.java`, `FlagsRoundMemberTest.java` and `MemberCases.java` (AZ-2120)
  - Loop 19: `Presence.java` (moved out of `Walker.java`, AZ-2342; `requireNothingDropped` for the split bit, AZ-2331), `ByteSink.maxRounds` and `Rounds.packTimes` (AZ-2329), `Rounds.requireNoLone` (AZ-2332); tests `SplitFormLoudPackTest.java`, `LoneBytesInRoundTest.java`, `TimesCountZeroTest.java`, `EqValueCheckedTest.java`, rows added to `RoundLimitsTest.java` and `ReferenceScopeTest.java`
  - Loop 20: no new main file; `ByteSink.java` (`maxBytes`, `maxSlots`, `startRound`, long growth), `Scheme.java` (`withMaxBytes`, `DEFAULT_MAX_BYTES`), `Rounds.java` (`repeat` cap, `nameOf`), `VarFields.java` (counts as full `u64`), `Presence.java`; tests `PackBudgetTest.java`, `LoneUtf8Budget.java`, `RepeatRoundCapTest.java`, `CountsFractionsSinkTest.java`, `ParityPinsTest.java` (run from `PackbinTest`; AZ-2354, AZ-2355, AZ-2356, AZ-2359, AZ-2360, AZ-2361) and the pack cases in `HostileVectorTest.java` (AZ-2367)
  - Loop 21: no new main file; `Rounds.java` (`width`, `requireListPerRound`), `Presence.java` (`requireCountWritten`, `childOn` with `valuesOnly`), `SchemeOrder.java` (empty body check, `counts`), `Field.java` (`countSource`), `ByteSink.java` (`startRound` takes the width). New tests: `RoundSlotWidthTest`, `EmptyRoundBodyTest`, `RepeatShortOptionalTest`, `ClearBitProbesTest`, `HostileRefusals`, `HostileLoop21`
  - Loop 22: no new main file; `Presence.java` (`positive(value, bias)`, the count check for `BITS`, `PACKED`, `SIZED`), `SchemeOrder.java` (count source for those kinds), `Scheme.java` (`DEFAULT_MAX_SLOTS` 1 048 576). New tests: `HostileLoop22.java`, `HostileRuleTableTest.java`, `UnpackMemory.java`; `ClearBitProbesTest`, `RoundLimitsTest`, `PackBudgetTest`, `HostileVectorTest`, `HostileRefusals` changed (AZ-2410, AZ-2415, AZ-2417, AZ-2418)
  - Loop 23: no main change. New test: `NoValueCountNestedTest.java` (AZ-2436), run from `PackbinTest`.
  - Loop 25: no source change. New test `src/test/java/packbin/Loop25ProbeD1D7Test.java`, called from `PackbinTest.java` (AZ-2478, AZ-2476).
- **Owns (exclusive write during implementation)**: `java/**`
- **Imports from**: none
- **Consumed by**: Android and other Java programs

> See ADR 001_runtime-primitives-no-generator.

### Component: go

- **Epic**: AZ-2222
- **Directory**: `go/` (module `github.com/zxsanny/packbin/go`, `go 1.26`; tags `go/vX.Y.Z`, ADR-004)
- **Public API**:
  - the exported identifiers of package `packbin` in `go/*.go` (non-test files); there is no `internal/` split
- **Internal (do NOT import from other components)**:
  - unexported identifiers in `go/*.go`; tests `go/*_test.go`, fuzz corpus `go/testdata/`
  - Loop 24 (AZ-2222): created
  - Loop 25 (AZ-2475, D8): new `go/mem_test.go` (build tag `packbin_memtest`, not part of `go test ./...`).
- **Owns (exclusive write during implementation)**: `go/**`
- **Imports from**: none (stdlib and `golang.org/x/crypto/chacha20` only)
- **Consumed by**: Go services

> See ADR 001_runtime-primitives-no-generator, ADR 004 (Go ships as a git tag, loop 24).

### Component: swift

- **Epic**: AZ-2223
- **Directory**: `swift/` (library target `Packbin`; manifest `Package.swift` at the repository root, `swift-tools-version: 6.0`, iOS 15, macOS 12; installed from the `vX.Y.Z` tag, ADR-005)
- **Public API**:
  - the `public` declarations in `swift/Sources/Packbin/` (one module `Packbin`)
- **Internal (do NOT import from other components)**:
  - `internal` declarations in `swift/Sources/Packbin/`; tests `swift/Tests/PackbinTests/`, fuzz and hostile loaders under the test target
  - Loop 26 (AZ-2223): created
- **Owns (exclusive write during implementation)**: `swift/**`, `Package.swift`, `Package.resolved`
- **Imports from**: none (Swift standard library; CryptoKit on Apple platforms, `swift-crypto` elsewhere)
- **Consumed by**: Swift programs

> See ADR 001_runtime-primitives-no-generator, ADR 005 (Swift installs from the root `Package.swift`, loop 26).

## Shared / Cross-Cutting

No shared code package. The library does not log, authenticate, or load configuration. Each package implements the connection session in its own public entry. None imports another.

### fixtures

- **Directory**: `fixtures/`
- **Purpose**: `golden.hex`, the position row `4001000065cd1d00a3e1110100`
- **Owned by**: AZ-1866
- **Consumed by**: all eight packages, as a file read, not an import

### fixtures/hostile

- **Directory**: `fixtures/hostile/`
- **Purpose**: `cases.txt`, packets and schemes that crafted input can send, with the expected outcome kinds; `check-cases.sh` checks the file format and `cases.test.sh` proves that check fails on corrupted copies. Since loop 15 (AZ-2220) the file held 19 cases; since loop 22 it holds 65 (unchanged in loop 23; ten added: three no-value count, two unequal `repeat` lists, a short `times` list under `flags`, a bytes-budget element case, three empty-`when` construct cases; `pack_slots_over_limit` and `pack_element_times_over_budget` renumbered for `maxSlots` 1,048,576), 55 since loop 21 (40 since loop 20, 33 since loop 19, 25 since loop 18); loop 18 added `eq_bool_false` (AZ-2126, a `construct` case every package builds by hand and expects refused) and a `pack` stage with five cases (AZ-2194; `pack_out_of_range_integer` is not run by C++, a typed row binds `std::uint8_t`), with `hostile_pack_cases.hpp` in the C++ runner and a loader test in each package; the `limit` stage (two cases, a `repeat` and a `times` past a low round limit) is replayed by C#, TypeScript, Java, Rust and (since loop 16) Python, and skipped by C++. Loop 19 added eight cases: `eq_out_of_range` (a `construct` case, AZ-2338) and seven `pack` cases (`pack_times_count_over_limit`, `pack_times_zero_with_values`, `pack_split_when_source_after_byte`, `pack_split_times_count_after_byte`, `pack_split_times_count_skipped`, `pack_lone_bytes_in_round`, `pack_split_false_condition_silent`); C++ skips two with reasons (`pack_times_count_over_limit`, `pack_lone_bytes_in_round`) in addition to `pack_out_of_range_integer`. Loop 20 added seven `pack` cases (AZ-2367): `pack_lone_utf8_under_times_over_budget`, `pack_element_times_over_budget`, `pack_slots_over_limit`, `pack_repeat_over_limit`, `pack_split_count_zero_after_byte_list`, `pack_split_count_zero_after_byte_scalar`, `pack_flags_skipped_count_with_values`; C++ runs two (the count 0 list and the skipped count) and skips five, Rust skips the element case (no `times` in a list element); the TypeScript loader (`PACK_REFUSAL`) and the C# loader pin the rule that fired, the Python, Java, Rust and C++ loaders assert refusal only (until loop 21). Loop 21 added fifteen cases (AZ-2394, `reference_loop21_slots.md`): `pack_round_slots_at_limit`, `pack_round_slots_over_limit`, `pack_round_slots_flags_at_limit`, `pack_round_slots_flags_over_limit`, `pack_flags_short_list`, `pack_flags_short_list_filled`, `pack_split_times_absent_body`, `pack_late_when_in_bit_body`, `pack_count_one_clear_when`, `pack_bits_count_clear_when`, `pack_packed_count_clear_when`, `pack_sized_count_clear_when` and the `construct` cases `construct_empty_times_body`, `construct_empty_repeat_body`, `construct_empty_round_body_list_element`; C++ skips seven and Rust two (stated in the fixture README); since AZ-2392 all six loaders name the rule or message each refused case must give
- **Owned by**: AZ-2070
- **Consumed by**: every package, as a file read. The C++ runner is `cpp/tests/core/hostile_host_tests.cpp`. Loop 26: `cases.txt` unchanged at 65; `check-cases.sh` counts eight package names (Swift, AZ-2519); `fixtures/hostile/fuzz/corpus.txt` (new, AZ-2517) holds 28 unpack fuzz inputs (the 12 unpack and limit packets of `cases.txt` and 16 from Go's seed corpus), read by the Swift `FuzzTests`

### fixtures/text

- **Directory**: `fixtures/text/`
- **Purpose**: the compact text format (loop 35, AZ-2646, AZ-2647): `tables.json` (the frozen code-length tables, alphabets and character lists; part of the wire format), `tables.report.md`, `vectors.txt` (text, bytes, refusals, ring packets and bit-flip rows that every package loads), `check-vectors.sh` and `check-vectors.test.sh` (re-derive every row with the reference codec, with mutants), `README.md`
- **Owned by**: AZ-2646, AZ-2647
- **Consumed by**: all eight packages, as a file read (their tests load `vectors.txt` and compare their emitted tables file with `tables.json`)

### scripts/text

- **Directory**: `scripts/text/`
- **Purpose**: `textfmt.py` (the reference encoder and decoder and a small command line), `train_tables.py` (trains and freezes `tables.json` from the Tatoeba corpus; `--check` reproduces it byte for byte), `gen_vectors.py`, `check_vectors.py`, `emit_tables.py` (emits the constants of `tables.json` as source for each language), `check-emitted.sh` and `check-emitted.test.sh` (each package keeps exactly the emitted file), `fuzz_reference.py`, `size_report.py`
- **Owned by**: AZ-2646, AZ-2647, AZ-2657
- **Consumed by**: the scaffold job of `test.yml` and `scripts/loop-tests.sh`; the package workers during implementation

### Compact text in the packages (loop 35)

Each package adds its codec next to its string walker and keeps the emitted tables file unedited (`python3 scripts/text/emit_tables.py <lang> --path` names it): C# `TextTables.cs`, `TextModes.cs`, `TextEdges.cs`, `TextEncoder.cs`, `TextDecoder.cs` (AZ-2650); TypeScript `src/text-tables.ts`, `src/text.ts` (AZ-2649); Python `_text_tables.py`, `_text_model.py`, `_text_encode.py`, `_text_decode.py` (AZ-2648); Rust `walk/text.rs`, `walk/text/encode.rs`, `walk/text/decode.rs`, `walk/text_tables.rs` (AZ-2652); C++ `include/packbin/text_tables.hpp`, `src/core/text.hpp`, `text_encode.hpp`, `text_decode.hpp` (AZ-2655, AZ-2656); Java `TextTables.java`, `TextModes.java`, `TextEncoder.java`, `TextDecoder.java` (AZ-2651); Go `text_tables.go`, `text_codes.go`, `text_encode.go`, `text_decode.go` (AZ-2653); Swift `TextTables.swift`, `Text.swift`, `TextEncode.swift`, `TextDecode.swift` (AZ-2654). The string walker functions of each package call the codec for a field, a list element, a dictionary key and a `repeat`, `times` or `flags` string.

### scripts

- **Directory**: `scripts/`
- **Purpose**: the loop's test run (AZ-2500, loop 25). `loop-tests.sh` runs the scaffold, the eight language suites in their CI containers (`swift` since loop 26; its scaffold stage also runs `ring-wiring-swift.test.sh`, and `ring-prepare.test.sh` since loop 33), the ARM stage, the ring, AC-10 and the publish gate; a stage runs only when a file it covers changed since its last stamped pass, the suites run in parallel with a serial retry, and the gate is skipped unless the publish path changed. `loop-tests.test.sh` tests the selection and the execution (a fake `docker`) and is a step of the `scaffold` job.
- **Owns (exclusive write during implementation)**: `scripts/**`
- **Consumed by**: step 11 and the loop smoke (`_docs/04_deploy/deployment_procedures.md` § Loop test script)

### workflows

- **Directory**: `.github/workflows/`
- **Purpose**: test on every branch push and pull request (jobs `scaffold` for the static checks, `suites` for the eight language suites and the `publish-gate-*` jobs for the publish gate test (one job in loop 28, AZ-2564, eight since loop 32, AZ-2625, guarded by `publish-jobs.test.sh`), the `embedded-*` jobs for the C++ targets, and `ring`, the cross-language hand-offs, loop 16); publish on a version tag, after `publish.yml` has called `test.yml` on the tagged commit (loop 14). The helper scripts (`run-suite.sh`, `publish-*.sh`, `stage-arduino.sh`, `report-row.sh`) and the `drivers/` for the language-pair run live in the same directory. Since loop 19 (AZ-2341) `run-suite.sh python` checks that its venv can import pytest and says how to rebuild it, and the hermetic `run-suite.test.sh` (fake venvs, no network) runs in the `scaffold` job of `test.yml`. `language-pair.sh` has the `roundflags` and `roundwhen` rings since loop 13 (AZ-2179): producers C#, TypeScript, Rust, Java and C++, readers TypeScript, Rust, Java and C++ (C# has no public reader, AZ-2092); the Rust driver builds them in `drivers/handoff-rust/src/rounds.rs`. The ring runs on every push and pull request in the `ring` job of `test.yml` (AZ-2193, loop 16): `ring-toolchains.sh` checks the six toolchain versions, `ring-cxx.sh` is the `CXX` wrapper that compiles C++ in the `gcc:16` image, and `ring-wiring.test.sh` (a `scaffold` step) guards the wiring. Since loop 33 (AZ-2626) `ring-prepare.sh` takes the driver preparation off the ring's critical path (`start`: the gcc and swift pulls and the Swift driver build in the background right after checkout; `build`: npm, the Rust and the Go driver at the same time; `wait`: bounded, names a failed build, one timing notice); `ring-prepare.test.sh` and `ring-wiring-swift.test.sh` are `scaffold` steps since then. Since loop 34 (AZ-2627) CI keeps the Swift build output in `actions/cache`; `run-suite.sh` and `ring-swift.sh` write the cache state (`PACKBIN_SWIFT_CACHE`, set only by `test.yml`) into the timing notices (`run-suite-swift.test.sh` S12, `ring-prepare.test.sh` row 1b). The `bitwhen` ring has a Python participant since loop 16: six hand-offs, C# to TypeScript, TypeScript to Python, Python to Rust, Rust to Java, Java to C++ and C++ to C#. The `listgroup`, `dictgroup` and `listflags` rings (AZ-2239, loop 16) send a list of groups, a dict of groups and a list of flags TypeScript to Python, Python to Java and Java to TypeScript (since loop 18, AZ-2307, the chain is TypeScript to Python, Python to Java, Java to C# and C# to TypeScript, with the driver `drivers/csharp/HandoffElements.cs`; it is a chain, not all pairs), with the bytes `01020001020304`, `01020001007801020100790304` and `010300010100020200`; each of the four packages then refuses the same packets cut short (`unpack-<kind>-short`). Rust (it refuses these schemes at construction) and C++ (it builds an invalid scheme) do not take part; C# takes part since loop 18 (AZ-2119 made it unpack group elements in loop 17; AZ-2310 and AZ-2307 made dictionary-mode pack of the rows and a `flags` element work), and `ring-wiring.test.sh` checks six C# lines. The Java driver is split into `Handoff.java` and `HandoffElements.java`. A pair that fails prints one line naming it, for example `python unpack-dictgroup failed on the bytes packed by typescript` or `typescript unpack-listgroup-short failed: it read a short element or the driver crashed (see the output above)` (AZ-2238, AZ-2239); `consumer_failure_checks` in `ring-wiring.test.sh` guards the first form. `run_lang` returns on a failed C++ compile or `javac`, so a stale binary cannot stand in for the build
- **Publish scripts** (loop 14, AZ-2095 to AZ-2097): `publish-gate.sh` (golden check, writes the plan), `publish-registries.sh` (entry point: plan, credential and tool preflight, build, upload; `PACKBIN_BUILD_ONLY=1` is the build-only dry run), `publish-build.sh` with `publish-inside.sh` (language packages in their toolchain image), `publish-embedded.sh` (vcpkg, PlatformIO, ESP-IDF, Arduino) and `publish-sign.sh` (Maven bundle signature), `publish-check.py` (artifact checks; since AZ-2240 also the npm `exports` and `types` and the relative imports of `dist/`, and the vcpkg port's `CMakeLists.txt`, `LICENSE` and host dependencies), `publish-upload.sh` with `publish-query.sh` and `publish-published.py` (existence queries), `publish-lib.sh` (target table `PACKBIN_TARGETS`, credentials, `publish_container` and `pip_install_pinned` since loop 15), `crates-token.sh`, `publish-position.sh`
- **Pins and read-only containers** (loop 15, AZ-2214, AZ-2215): `tool-pins.txt` (one exact version per tool) and `tool-pin.sh` (prints one) are read by `publish-lib.sh`, `publish-inside.sh`, `run-suite.sh`, `publish.yml` and `cpp/embedded/examples.sh`; every non-local `uses:` is a commit SHA with a tag comment. `docker-compose.publish.yml` (repo root, the second compose file) mounts the repo read-only in the golden-gate and build containers, and only `publish_container` passes it
- **Publish tests**: `publish-gate.test.sh` (workflow structure parsed with Ruby `yaml`, gate and static checks; it sources `publish-phases.test.sh` for the two-phase scenarios and `publish-rerun.test.sh` for the credential matrix, re-run and registry scenarios); each file stays at or under 500 lines (`publish-phases.test.sh` was 501 lines, one over, since the C# multi-target commit `68ca4f8`; loop 31 (AZ-2607) moved its three failure scenarios `ph_failure_injection`, `ph_fabricated_checks` and `ph_pipeline_violations` unchanged into `publish-phases-failures.test.sh`, so the two files are 323 and 193 lines, and `publish-gate.test.sh` is 393, so a new check goes in a new sibling file). Loop 15 added two such files, sourced by `publish-gate.test.sh`: `publish-pins.test.sh` (the `uses:` pin check, the pins file and its reader, the pip install lines, AZ-2214) and `publish-readonly.test.sh` (the read-only mount in every service, the artifacts mount, the unchanged tree after a gate and a build-only run, AZ-2215). Loop 16 added `publish-vcpkg.test.sh` (AZ-2098: the vcpkg port staged into a bare registry by the real `publish-registries.sh`, a consumer install and link through the vcpkg of the runner, the `add_subdirectory` targets; AZ-2232 added the `supports` check, the version-rule check and a second consumer project, and AZ-2240 the guard checks on the staged port; `bash publish-gate.test.sh --vcpkg` runs only these; it prints `NOT RUN` without vcpkg and the gate's last line names it) and `publish-npm.test.sh` (AZ-2103: the npm tarball layout checks of `publish-check.py`, `package.json` and a build through the real `publish-inside.sh`; `bash publish-gate.test.sh --npm` runs only these; AZ-2240 added `npm_guard_checks`, the guard on the real tarball and its mutants). `publish-position.test.sh` (AZ-2238) is a plain script that the gate runs as a child process, in the full run and in `--npm`: `publish-position.sh typescript` on a tree without `typescript/node_modules`
- **Go** (loop 24, AZ-2222): `run-suite.sh go` runs `gofmt -l`, `go vet`, `go test -race -v`, a 60 s `FuzzUnpack` (a named skip line while no `FuzzUnpack` exists) and the one-dependency check (the modules of the built packages are the main module and `golang.org/x/crypto`); it fails without `go/go.mod` (AZ-2448, `run-suite.test.sh` G1 to G10, a `go` service in both compose files); since loop 25 the other six languages fail without their manifest too (AZ-2477). `ring-go.sh` builds the Go ring drivers (`go` on the runner, else the `golang:${RING_GO}` image) and `drivers/handoff-go/` is the driver module, with a `replace` to `go/` and the `position` program that prints the golden hex (AZ-2449; `language-pair.sh` has the Go hand-offs for the same kinds as the other languages, and `ring-toolchains.sh` checks `go`). `publish-go.sh` pushes the `go/vX.Y.Z` tag after the golden gate and checks `proxy.golang.org` (AZ-2450, ADR-004)
- **Swift** (loop 26, AZ-2223): `run-suite.sh swift` (the `swift:6.3.3` image) resolves, tests, and builds release with warnings as errors and strict concurrency (the one release build, with the tests, since loop 32), fuzzes, runs the thread sanitizer and the release speed tests, and checks the one dependency `swift-crypto`; it fails without `Package.swift` or `swift/` (AZ-2521, `run-suite-swift.test.sh`). `ring-swift.sh` builds `drivers/handoff-swift/` (the handoff driver and the `position` program, on the root package by path) into a scratch dir outside the repo, with the runner's `swift` or the `swift:${RING_SWIFT}` image (AZ-2522, `ring-wiring-swift.test.sh`); `publish-position.sh swift` runs that `position` program for the ring and the golden gate (on a copy named `packbin` when the root is the gate container's `/src`). Swift ships no artifact and no tag: `swift-check`, the last publish target, runs `publish-swift.sh`, a throwaway consumer that resolves `https://github.com/zxsanny/packbin` at exactly `X.Y.Z` (the `vX.Y.Z` commit) and builds `Packbin` (AZ-2523, ADR-005; `publish-swift.test.sh` and `publish-swift-gate.test.sh`, sourced by `publish-gate.test.sh`)
- **Loop 25** (AZ-2477): `run-suite.sh` has a `missing_manifest` helper and every language branch fails when its manifest is missing; `run-suite.test.sh` M1 to M3 pin it. `language-pair.sh` builds the C# and C++ drivers once a run into a private `mktemp -d` directory and runs the built artifact (the ring 239 s to 43 s). `fixtures/hostile/check-cases.sh` counts the package names with one word list per pack case.
- **Owned by**: AZ-1866 owns `test.yml` and the workflow files existing. AZ-1875 owns the publish behavior in `publish.yml`; AZ-2095 to AZ-2097 own the structure of `publish.yml` and the publish scripts and tests above; AZ-2214 and AZ-2215 own the pins and the read-only containers
- **Consumed by**: the six registries

> See ADR 002_publish-from-version-tag.

## Allowed Dependencies (layering)

The eight packages are peers. None imports another.

| Layer | Components | May import from |
|-------|------------|-----------------|
| 1. Packages | csharp, typescript, python, rust, cpp, java, go, swift | none |
| 0. Fixture and workflows | fixtures, .github/workflows | none |

## Layout Conventions (reference)

| Language | Root | Per-component path | Public API file | Test path |
|----------|------|-------------------|-----------------|-----------|
| C# | `csharp/` | `csharp/` | `csharp/Packbin.cs` | `csharp/tests/` |
| TypeScript | `typescript/` | `typescript/src/` | `typescript/src/index.ts` | `typescript/tests/` |
| Python | `python/` | `python/src/packbin/` | `python/src/packbin/__init__.py` | `python/tests/` |
| Rust | `rust/` | `rust/src/` | `rust/src/lib.rs` | `rust/tests/` |
| C++ | `cpp/` | `cpp/include/packbin/`, `cpp/src/core/` | the headers in `cpp/include/packbin/` | `cpp/tests/core/`, `cpp/tests/compile-fail/` |
| Java | `java/` | `java/src/main/java/packbin/` | `java/src/main/java/packbin/Packbin.java` | `java/src/test/` |
| Go | `go/` | `go/` (one package `packbin`) | exported identifiers in `go/*.go` | `go/*_test.go` |
| Swift | `swift/` (manifest `Package.swift` at the root) | `swift/Sources/Packbin/` | `public` declarations of module `Packbin` | `swift/Tests/PackbinTests/` |
