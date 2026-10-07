# Batch Report

**Batch**: 1 (loop 17, C# wave C1, two worker stages on `csharp/`)
**Tasks**: AZ-2092, AZ-2093, AZ-2135 (C# part), AZ-2128 (C# part)
**Date**: 2026-10-07

One worker owned `csharp/`; stage 1 (AZ-2092, AZ-2093) was checked and committed as `0f60607` before stage 2 (AZ-2135, AZ-2128) started. The first worker run stalled before editing anything (stream watchdog, tree clean) and was resumed with the same context. Per the owner's direction (2026-10-06) there is no per-batch review and no per-batch Docker run: the worker ran its own suites and a differential against an export of the previous commit, the parent re-ran both targets before each commit; one total review and one total test run follow at the end of the loop.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2092_csharp_scoped_binding | Done, AC-7 partly met (below) | `Field.cs`, `FieldAccess.cs`, `FlagScopes.cs`, `Packbin.cs`, `Scope.cs`, `Walker.cs`, `Walker.Counted.cs` (464 lines), `Walker.Presence.cs`, `Walker.Rounds.cs`; new `FieldBinding.cs` (93), `RowBinding.cs` (209), `Bound.cs`; `ObjectValues.cs` deleted | +24: `TypedParityTests` (10, pass on `68ca4f8` too: they pin the bytes before the rewrite), `TypedBindingTests` (11, 9 fail on `68ca4f8`), `NestedRowFlagByteTests` (3) | AC-7 shortfall; construction refusals for nested flag bytes (discovery 1) |
| AZ-2093_csharp_ac10_public_path | Done | `tests/PackbinTests.cs` | `Nfr_PublicTypedPackAndUnpack_RoundTripsWithinOneSecond` times only `Pack(Target, row)` and `Unpack(bytes, Target.On(...))`, bound unchanged at 1.0 s | none |
| AZ-2135 (C# part, G4) | Done | `Field.cs`, `FlagGroup.cs`, `FlagScopes.cs` (`Validate` replaced by `Bind`), `Packbin.cs` | +8 `SplitBitOrderTests` (all fail on `0f60607`); `BoolFlagRuleTests.Ac6_NinthBitOnOneFlagByte` rewritten (the old assertion was the behaviour G4 reverses) | README and `schema.md` still say "C# is not changed yet" (step 13) |
| AZ-2128 (C# part) | Done for nested `Flags` and split `FlagBit` children | `Walker.Presence.cs` (+4/-1) | +9 `FlagGroupPresenceTests` (4 fail on `0f60607`) | the held `when`/`times`/`repeat` angle is untouched; discoveries 12 and 13 |

AC status of AZ-2092: AC-1 (`01 01 02`), AC-2 and AC-3 (README example packs and unpacks the README hex), AC-4 (`01 02 00 03 04`), AC-5 (parity tests), AC-6, AC-8 (every existing byte, golden) pass; AC-7 is **partly met**: the AC-10 test takes 274 to 284 ms in Debug (was 791 ms at `68ca4f8`), the Release test run 304 to 348 ms (was 641 to 656 ms), the standalone Release cold pass 267 to 278 ms (was about 570 ms) and 57 ms warmed (was 150 ms). That is 2.0x cold and 2.6x warmed, not the spec's 3x; the "at most 300 ms" target is met in the standalone cold pass and missed by a little in the Release xunit run; the project bound of 1 s (AC-10) has about 3x margin. Going lower needs a typed walker that does not go through a dictionary (the engine alone costs 130 ms cold): owner decision whether to spec it.

AZ-2135 probes (row with `A`, `B`, `X` as `byte?`), `0f60607` against the new build: one handle in two schemes `[m, m.Bit(u8 x)]`, x=5: `010305` to `010105` / `010105`; `[m, early a, late b]` (late created first), b=9: `010109` to `010209`; `[m, m.Bit(a), m, m.Bit(b)]`, b=9: `01020209` to `01000109`: the Rust bytes in all three. Further: a handle shared by two 5-bit schemes builds both (it threw at the ninth `.Bit` call); two reads of eight bits each pack `01 80 01 02 02`; a nested row reads its own byte (`01 03 01 01 02 03`, was `01 05 01 02 02 03`); the ninth bit of one read is refused when the scheme is built; a bit that is created and never placed no longer takes a number (`010205` with a flag set and no value, now `010105`).

AZ-2128 probes (`Flags(0, Group(0, Mark, Flags(0, U8 B)))`, B=5): nested `Flags` and split form give `01 01 01 05` (was `0100`, B dropped); with a required `U8 C` unset the pack fails `'C': flag group 'Mark' is set, so it needs a value` (was `0100`); B=5, C=7 packs `01 01 01 05 07`; only C=7 `01 01 00 07`; nothing set `0100`.

## Code Review Verdict

Not run for this batch (owner direction, memory `one-total-review-and-test`); covered by the one total review of loop 17.

## Test Suite

C# only, host toolchain (no Docker): net10.0 448 pass after stage 1 and 465 after stage 2 (424 at the start of the loop); `-p:PackbinTarget=netstandard2.0` 448 and 465; no warnings; no failures; none skipped. Public API: reflection dumps of the public and protected members of `Packbin.dll` at `68ca4f8`, after stage 1 and after stage 2 are identical (150 lines, empty diff) on both targets. Differentials against an export of the previous commit: stage 1, 14 schemes x 30 000 seeds (420 000 `Read`, 420 000 typed `Unpack`, 420 000 typed `Pack`, 1 379 563 lines): 0 outcome mismatches (6 298 lines in the `deep` scheme differ only in the error text, which now names the nested row); stage 2, 21 schemes x 20 000 seeds (1 380 490 lines): 0 differences for the old catalog and for field-order numbering (oracle: the previous build with one handle per read), 2 563 typed-pack lines differ in the presence schemes, all of them B set with C and the group unset, where `0100` became the loud `ArgumentException` naming `'C'`. Throughput and allocation: a 1 MiB packet of 16 lists x 65 535 one-byte elements allocates 285 MB typed (276 MB before, +3%). Not run in this batch: `language-pair.sh`, the hostile vectors of the other packages, Docker (step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A nested row starts with no flag byte visible and a byte read inside it is not visible after it. New construction refusals: `[m, Group(g, m.Bit(x))]` and `[Group(g, m, ...), m.Bit(x)]`; both built before because nested members were merged into flat names. This is the Java AZ-2233 rule (owner decision of loop 16) | AZ-2092 Outcome, AZ-2135 | keep; README upgrade-note line (step 13) | clear |
| 2 | A non-null typed nested row whose members are all null leaves a flags group's bit clear and the object is dropped silently (as at `68ca4f8`); a set group with a null nested row fails naming the row | AZ-2092, AZ-2128 | keep; option: a non-null member object counts as present (it would fail loudly). Owner | unclear |
| 3 | The element rule has two modes: pack decides by the runtime type of the item (`is` the element field's row type), unpack by the collection's declared element type; a `List<object>` holding row objects packs but unpacks as raw values | AZ-2092 Flagged concerns | README paragraph (step 13) | clear |
| 4 | Collection members unpack only as `E[]`, `List<E>`, `Dictionary<string,E>` (and types assignable from them) or a concrete class with a parameterless constructor; `Stack<int>` still throws `InvalidCastException` at unpack, as before | AZ-2092 Scope | optional: refuse unsupported collection members at construction | unclear |
| 5 | AC-4 wording (`Holder`, `Item`) read as `List<Holder>` with `Group((Holder h) => h.Item, ...)`; typed group elements now work, so AZ-2119 AC-1 and AC-2 are covered for typed rows, dictionary rows still throw `KeyNotFoundException` | AZ-2092 AC-4, AZ-2119 | AZ-2119 keeps its dictionary-mode part (batch 2) | clear |
| 6 | Typed `Unpack` of `repeat`/`times` rows still throws `InvalidCastException` (carried F17); a nested row inside a typed round hits the same | AZ-2092 Excluded | none now; security audit re-verifies | clear |
| 7 | Pack error text changed in two places, both `ArgumentException`: an absent nested row outside flags names the row (`'Inner' has no value`); a set group with a null nested row names the nested row, not its first child | AZ-2092 | none | clear |
| 8 | `Expression.Compile` runs when a `Field` is built (two delegates per field); trimmed or AOT apps interpret the expressions. Suite time unchanged | AZ-2092 NFR | one sentence in the README Unity/IL2CPP note if AOT is supported | unclear |
| 9 | The C# language-pair driver `Handoff.cs` needs no typed case: the typed README example already produces the README bytes | AZ-2092 Blackbox AC-2 | none | clear |
| 10 | Unpack numeric setters cast a `double` read directly to a member of the field's own width (exact); other numeric conversions still use `Convert.ChangeType` | AZ-2092 | none | clear |
| 11 | AZ-2092 AC-7 (3x faster) is not met, see Task Results | AZ-2092 AC-7 | owner: accept (project AC-10 has 3x margin) or spec a dictionary-free typed walker | unclear |
| 12 | A direct `u2` member of `Flags` with only a non-first slot present (dictionary rows) is dropped silently: `Flags(U2((0,A),(1,B)))` with `{B:2}` packs `0100` (`BitOn` looks at the first slot name only; `{A:1}` alone fails naming B). Typed rows are not affected (u2 slots are non-nullable). Not in the C# probe table | AZ-2128 Outcome ("any value, any kind") | make `BitOn` true when any u2 slot is present: one line plus a test, silent drop becomes a loud pack error; done in batch 2 | clear |
| 13 | A `when` inside a group under `Flags` is still ignored by presence (`k=1 v=9` packs `01 01 00`); `times` and `repeat` not probed | AZ-2128 held concern, AZ-2120 | unchanged, held with AZ-2120 | unclear |
| 14 | `Field.Flags(...)` (combined form) still refuses its ninth member when `Field.Flags(...)` is called, not when the scheme is built; the spec moves only the split form | AZ-2135 | none | clear |
| 15 | Behaviour changes for the README upgrade note: the handle holds no bit; it can be shared by any number of schemes and read more than once; a bit created and never placed no longer counts; the ninth bit is refused at scheme construction, not at `.Bit(...)`; a nested row is a flag-byte scope of its own | AZ-2135 | step 13: README (the line "C# is not changed yet: build the bits in scheme order there") and `schema.md` | clear |

## Commit

Stage 1: `0f60607 [AZ-2092] [AZ-2093] Bind typed C# rows per scope and time the public path in AC-10`. Stage 2 and the batch records: `[AZ-2135] [AZ-2128] Number C# split bits by field order and count nested flag groups` (trailer `Loop: 17`).

## Next Batch

Batch 2: AZ-2180, AZ-2181, AZ-2182, AZ-2119, AZ-2191, the C# parts of AZ-2114, AZ-2115, AZ-2121, plus the one-line `u2` presence fix (discovery 12) under AZ-2128.
