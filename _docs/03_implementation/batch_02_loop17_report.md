# Batch Report

**Batch**: 2 (loop 17, C# wave C2, two worker stages on `csharp/`)
**Tasks**: AZ-2180, AZ-2181, AZ-2182, AZ-2119, AZ-2191, AZ-2128 (`u2` follow-up), AZ-2114 (C#), AZ-2115 (C#), AZ-2121 (C#)
**Date**: 2026-10-07

A fresh worker owned `csharp/`: stage A (the code specs) was checked and committed as `a4cc089` before stage B (the three tests-only specs and one count fix) started. Per the owner's direction (2026-10-06) there is no per-batch review and no per-batch Docker run: the worker ran its own suites and differentials against an export of the previous commit, the parent re-ran both targets before each commit; one total review and one total test run follow at the end of the loop.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2180_csharp_flag_group_clone | Already held after AZ-2135 (batch 1), pins only, no code change | none | `FlagGroupCopyTests` 7, all pass; AC-1, AC-2 and AC-4 fail on `68ca4f8` and were fixed by AZ-2135 | the `Flags` group object is shared by reference between schemes that reuse the field; it is never mutated, so no clone |
| AZ-2181_csharp_count_integer_only | Done (the `when` half stays with AZ-2126) | `Packbin.cs` (+29/-14), `Walker.Counted.cs` (`RequireCount`), `Walker.Rounds.cs`, `Walker.Scalars.cs` | `CountKindTests` 44 (35 fail on `0f60607`), `CountOverflowTests` 21 (20 fail on `a4cc089`) | six hostile float-count tests and three count-type assertions reversed by owner decision |
| AZ-2182_csharp_nonlist_round_value | Done | `Walker.Rounds.cs` (+47/-3, 186 lines) | `LoneRoundValueTests` 26 (20 fail on `0f60607`) | broadcast changes bytes for rows that packed before (discovery 6) |
| AZ-2119_csharp_group_list_element | Done for unpack, dictionary and typed | new `Walker.Elements.cs` (13), `RowBinding.cs` | `GroupElementTests` 10 (7 fail on `0f60607`) | dictionary-mode pack of a group element still fails (discovery 3) |
| AZ-2191_csharp_dict_pack_strict | Done | new `Walker.Numbers.cs` (79), `Walker.Scalars.cs` | `StrictNumberTests` 50 (25 fail on `0f60607`) | char, enum, object refused (discovery 9) |
| AZ-2128 (`u2` follow-up) | Done | `Walker.Presence.cs` (+3/-1) | `U2PresenceTests` 8 (2 fail on `0f60607`) | `when`/`times`/`repeat` under `Flags` untouched (held with AZ-2120) |
| AZ-2114 (C#) | Done, stand-in scheme | none | `HostileSessionTests` 6, tests only | the README `when` scheme for `01 00 ff` is refused at construction in C# too |
| AZ-2115 (C#) | Done | none | `SplitFormReferenceTests` 3, tests only | none |
| AZ-2121 (C#) | Done | none | `FlagScopeContainerTests` 9, tests only | none |

Existing tests changed by owner decision (2026-10-06, AZ-2181 reverses C# AZ-2088 AC-6), none weakened, skipped or deleted: six `HostileUnpackTests.Counts.cs` float-count tests (`Count_F32NaN`, `Count_F32PositiveInfinity`, `Count_F32NegativeInfinity`, `Count_F64Huge`, `Count_F64HugeNegative`, `Count_F64NaN`): the old assertion was `ShortPacket(P)` for hostile float count bytes, the new one is `ArgumentException` at scheme construction naming `'P'` and the float field (renamed `..._SchemeIsRefused`; the unused `FloatHex` and `DoubleHex` helpers are gone); three `WrittenCountTests` sites (6 cases): `Assert.IsType<InvalidOperationException>` became `Assert.IsType<ArgumentException>`, the message `count 'N' is missing` is unchanged.

## Code Review Verdict

Not run for this batch (owner direction, memory `one-total-review-and-test`); covered by the one total review of loop 17.

## Test Suite

C# only, host toolchain (no Docker): net10.0 610 pass after stage A and 649 after stage B (465 at the start of the batch, 424 at the start of the loop); `-p:PackbinTarget=netstandard2.0` 610 and 649; no warnings; none failing; none skipped. Public API: reflection dumps of the public and protected members of `Packbin.dll` against the previous commit are empty on both targets for both stages (150 lines each). Differentials against an export of the previous commit: stage A, 21 schemes x 20 000 seeds (about 1.67M lines a side, 1 259 997 matched keys), counts over 9 integer widths x every counted kind x 5 000 random and 5 000 hostile packets (90 000 hostile cases, 0 differences), 6 744 differences, every one in a class the specs name: (a) group list/dict elements `KeyNotFoundException` became a value, short packet or trailing bytes (4 242 dictionary `Read` plus 512 typed unpack cases); (b) 533 number cases: fractions, bool, string, char/enum and f32 overflow are refused, `OverflowException`/`FormatException`/`InvalidCastException` became `ArgumentException`, no value that packed before packs differently; (c) rounds, about 8 000 cases: a lone scalar to every round (about 600 threw before), 103 cases where a scalar under a flag now sets the bit in every round (bytes change), a lone `byte[]` `ArgumentException`, 7 cases where an empty lone `byte[]` (zero rounds, `01`) is refused; (d) `u2` second slot only: bytes became `ArgumentException`; (e) 245 typed `times` rows threw "has no value" for rounds past 0 and now pack. Stage B: 936 pack cases (9 count sources x 4 kinds x 26 values), 60 differ, all `OverflowException` becoming `ArgumentException` naming the count, the other 876 identical, no wire byte changed. Not run in this batch: `language-pair.sh`, the hostile vectors of the other packages, Docker (step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The `when` half of the owner decision (float, utf8, bytes refused; a bool only with `true`) is not implemented here: AZ-2181 lists it as excluded and assigns it to AZ-2126; `FloatWhenTests` and `WrittenWhenKindsTests` still assert a float `when` works | AZ-2181 Excluded, AZ-2126 | do it with AZ-2126, reverse those tests then | unclear (was it meant for this loop?) |
| 2 | The `Flags` group object is shared by reference by schemes that reuse one `Flags` field; immutable, no clone made | AZ-2180 Scope | none; a clone would have no observable effect | clear |
| 3 | Dictionary-mode pack of a list or dict with group elements still fails (`'A' has no value`): the item is put under the group's name instead of being flattened; unpack-then-repack of dictionary rows does not round-trip for group elements | AZ-2119 | follow-up spec, about 1 point | clear |
| 4 | `Flags` (and other containers) as a direct list or dict element still throws `KeyNotFoundException` (key `""`) in `Read`; this is the `listflags` ring shape and C# does not take part in that ring | AZ-2119 | follow-up: reuse `ElementValue` for `Flags` elements plus the typed side | unclear |
| 5 | `List` and `Dict` names in a round (AZ-2182 flagged row 3, open): a lone `IList` for a `List` name stays a list of rounds; a lone `IDictionary` for a `Dict` name is now broadcast to every round because it is not an `IList` (HEAD threw `'M' has no value`); a lone `string` for a `Utf8` name broadcasts, as in the other packages | AZ-2182 | owner decides whether a lone dictionary is refused like a lone collection | unclear |
| 6 | Broadcast changes bytes for rows that packed before: a lone scalar under `Flags` or a flag bit now sets the bit in every round (103 differential cases, `01 01 05 01 00 02` became `01 01 05 01 01 05 02`); the Rust map `times` gives a lone scalar to round 0 only, so option A needs a Rust follow-up with no ticket yet | AZ-2182 NFR, flagged row 2 | README upgrade note (step 13); Rust follow-up spec | clear |
| 7 | An empty lone `byte[]` for a `Bytes`/`Sized` name is refused (it was zero rounds, `01`); an empty `List<int>` or `object[]` for a `Bits`/`Packed` name stays a list of zero rounds (indistinguishable) | AZ-2182 AC-4 | none | clear |
| 8 | A lone non-collection (an `int`) for a `Bytes`/`Sized` name is broadcast and then fails in `PackBytes` with a raw `InvalidCastException`, as outside a round | AZ-2182, AZ-2191 | type check in `PackBytes`/`PackSized`, same family as strict numbers | unclear |
| 9 | char, enum and `object` values for numeric fields were converted through `IConvertible` before (`'a'` became 97); they are refused now because the spec's refused classes are bool, string and fraction | AZ-2191 | keep, README upgrade note | unclear |
| 10 | A whole `decimal` is accepted for integer fields; a double beyond long..ulong is refused, 2^63 is accepted for `u64` and refused for `i64`, -0.0 is accepted | AZ-2191 AC-4 | none | clear |
| 11 | `u2` slots, `bits` and `packed` items still round or coerce (a `1.5` in a `u2` slot packs as 2); a fractional `u2` slot count still rounds | AZ-2191 Flagged row 1 | follow-up, as recorded in the plan | clear |
| 12 | Dictionary-mode unpack of a group element returns the internal `Scope` instance (a `Dictionary<string, object?>`), as the top-level result already does; no wrapper under the group's name | AZ-2119 AC-1 | none | clear |
| 13 | A typed row's `Bytes` member inside `repeat`/`times` is now always refused (it can only be a lone `byte[]`; before, `InvalidCastException`) | AZ-2182 AC-4 | none | clear |
| 14 | Typed anchored group elements threw `KeyNotFoundException` on `68ca4f8` and `0f60607`; fixed together with AZ-2119 because the AC says no exception escapes | AZ-2119 | none | clear |
| 15 | The README `when`-based zero-progress scheme for `01 00 ff` is refused at construction in C# (same as Rust and Java); the AZ-2114 tests use `Repeat(Bytes(0))` as the stand-in | AZ-2114 AC-1 | none | clear |
| 16 | A plain session waiter cannot pack hostile bytes: the AZ-2114 tests pad hand-built clear bytes with the opener's keystream through reflection on `_send`/`_sendCount` (the pattern `TopRangeAndSessionTests` already uses); a public way to pad arbitrary bytes would be a new API, out of scope | AZ-2114 AC-2 | none | clear |
| 17 | AZ-2121 AC-4 text names no C# test for "bit whose byte comes after" and "second member"; added, mirroring Java | AZ-2121 AC-4 | keep | clear |

## Commit

Stage A: `a4cc089 [AZ-2181] [AZ-2182] [AZ-2119] [AZ-2191] Tighten C# counts and numbers`. Stage B and the batch records: `[AZ-2114] [AZ-2115] [AZ-2121] Pin C# hostile session, split-form and flag-scope cases` (trailer `Loop: 17`).

## Next Batch

All C# tasks of the plan are complete; the loop continues with step 10.5 (feature assessment, run once), then the one total review and step 11.
