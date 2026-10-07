# Feature assessment — loop 17

loop: 17
feature: csharp-stream (typed binding per scope, split-bit order, counts, rounds, strict numbers)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-07
**Implement pass**: batches 01 and 02 (`_docs/03_implementation/batch_01_loop17_report.md`, `batch_02_loop17_report.md`); no `implementation_report_*_loop17.md` and no completeness report yet (written by the loop close; the batch reports carry the discovery tables)
**Verdict**: CLARIFY — 20 covered / 4 out-of-scope / 3 gap-clear / 8 gap-unclear

Input notes: `scenarios.md` is absent for these specs (they were written in loops 11 to 13, before the scenario matrix); the intent baseline is the specs in `done/`, the loop plan and `handoff17.md`. Both batch reports carry the mandatory discovery table (32 rows, merged below). **Routing decision (owner preference, memory `one-total-review-and-test`, 2026-10-06): no re-entry round.** The `gap-clear` and `gap-unclear` rows are recorded in the loop 18 handoff instead of chaining `new-task --extend/--clarify`, because the owner asked that `todo/` stop growing during a loop. `assess_round` stays 0.

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| D1 | a flag byte read inside a nested row stays inside it; a bit outside it, or a byte outside and a bit inside, is refused at construction | covered | AZ-2135 progress rule (Java AZ-2233 rule); `NestedRowFlagByteTests` (3), `SplitBitOrderTests`; `FlagScopes.Bind` | batch_01 #1 |
| D3 | list/dict element: a row-typed item is walked through its accessor, any other item is the element value | covered | AZ-2092 AC-4, AC-5; `TypedBindingTests` (`Tag[]`, `Dictionary<string,Tag>`), `TypedParityTests`; `RowBinding.Element` | batch_01 #3 |
| D5 | typed group elements in lists and dicts (AZ-2119 for typed rows) | covered | AZ-2092 AC-4, AZ-2119 AC-1, AC-2; `TypedBindingTests`, `GroupElementTests`; `RowBinding.cs` | batch_01 #5, batch_02 #14 |
| D7 | pack error texts name the nested row | covered | AZ-2092 AC-1; `TypedBindingTests`; `RowBinding.Read` | batch_01 #7 |
| D9 | the typed README example needs no `Handoff.cs` typed case | covered | AZ-2092 AC-2, AC-3; `TypedBindingTests` (README hex packs and unpacks) | batch_01 #9 |
| D10 | unpack numeric setters cast a `double` to the field's own width | covered | AZ-2092 AC-8; `TypedParityTests` (every width); `FieldAccess.cs` | batch_01 #10 |
| D12 | a direct `u2` member of `Flags` with only a non-first slot present | covered | AZ-2128 Outcome "any value, any kind"; `U2PresenceTests` (8); `Walker.Presence.cs` `BitOn` | batch_01 #12 |
| E2 | a `Flags` group object shared by reference between schemes | covered | AZ-2180 AC-1 to AC-5; `FlagGroupCopyTests` (7); `FlagScopes.Bind` | batch_02 #2 |
| E7 | an empty lone `byte[]` is refused, an empty list for `Bits`/`Packed` stays zero rounds | covered | AZ-2182 AC-4; `LoneRoundValueTests`; `Walker.Rounds.cs` `RequireRoundCollections` | batch_02 #7 |
| E10 | whole `decimal`, range edges, -0.0 for integer fields | covered | AZ-2191 AC-4; `StrictNumberTests` (50); `Walker.Numbers.cs` | batch_02 #10 |
| E12 | dictionary-mode unpack of a group element returns the internal `Scope` row | covered | AZ-2119 AC-1 ("shape matches the other five packages"); `GroupElementTests`; `Walker.Elements.cs` | batch_02 #12 |
| E13 | a typed `Bytes` member inside `repeat`/`times` is always refused | covered | AZ-2182 AC-4; `LoneRoundValueTests` (typed cases) | batch_02 #13 |
| E14 | typed anchored group elements | covered | AZ-2119 AC-1; `GroupElementTests` (3 typed cases); `RowBinding.Element` | batch_02 #14 |
| E15 | README `when` zero-progress scheme is refused at construction | covered | AZ-2114 AC-1; `HostileSessionTests` (6, `Repeat(Bytes(0))` stand-in as in Rust and Java) | batch_02 #15 |
| E16 | a waiter cannot pack hostile bytes; tests pad with the opener keystream | covered | AZ-2114 AC-2; `HostileSessionTests`; `TopRangeAndSessionTests` pattern | batch_02 #16 |
| E17 | AZ-2121 shapes: bit after its byte, second member | covered | AZ-2121 AC-4; `FlagScopeContainerTests` (9) | batch_02 #17 |
| N1 | one `FlagByte` handle used while schemes are built concurrently | covered | AZ-2180 AC-4; `FlagGroupCopyTests`; `FlagScopes.Bind` | assess-round-1 |
| N2 | a nested or element row type without a public parameterless constructor | covered | AZ-2092 NFR Reliability; `TypedBindingTests` (2); `FieldBinding.Creator` | assess-round-1 |
| N3 | boundary values of counts (int range, u32, u64, i64 min) | covered | AZ-2181 follow-up; `CountOverflowTests` (21), `CountKindTests` (44); `Walker.Counted.cs` `RequireCount` | assess-round-1 |
| N5 | the `netstandard2.0` build gives the same results as net10.0 | covered | `TargetParityTests`; every test above passes on both targets (649 and 649); README states the .NET Standard build is tested on the .NET 10 runtime | assess-round-1 |
| D6 | typed `Unpack` of `repeat`/`times` rows throws `InvalidCastException` (carried F17); README says unpack never throws | out-of-scope | AZ-2092 `### Excluded`: "Typed `repeat`/`times` binding to collections of rows". The README wording is a step 13 fix; the security audit re-verifies | batch_01 #6 |
| D13 | `when`, `times`, `repeat` directly under `Flags` or inside a group under `Flags` are ignored by presence | out-of-scope | plan17 `Held`: AZ-2120 held by owner 2026-10-07 together with the six-package decision | batch_01 #13, batch_02 AZ-2128 |
| D14 | `Field.Flags(...)` refuses its ninth member at the call, not when the scheme is built | out-of-scope | AZ-2135 Scope: the spec moves the split form only | batch_01 #14 |
| E1 | a `when` on float, utf8 or bytes refused; bool only with `true` | out-of-scope | AZ-2181 `### Excluded` assigns the `when` kinds to AZ-2126 (held: six packages and the `eq_bool_false` vector); `FloatWhenTests` and `WrittenWhenKindsTests` still assert float `when` works | batch_02 #1 |
| E3 | repack of dictionary rows whose list/dict elements are groups (unpack then pack) | gap-clear | quote: "the value shape matches what the other five packages return for the same scheme" (AZ-2119 AC-1) and the project lesson "unpack-random-bytes then repack" → Given the rows `Read` returns for a list of group elements When they are passed to dictionary `Pack` Then the same bytes come out (today `'A' has no value`) | batch_02 #3 |
| E6 | a lone scalar in a `times` round of the Rust map API goes to round 0 only | gap-clear | quote: "DECIDED, the proposed default: option A: broadcast a lone scalar to every round, refuse a lone collection" (AZ-2182 Owner decision) → Given a Rust map scheme with `times` and a lone scalar When packed Then every round carries it, as in TypeScript, Python, Java and now C# | batch_02 #6 |
| E8 | a lone non-collection (an `int`) for a `Bytes` or `Sized` name fails with a raw `InvalidCastException` | gap-clear | quote: "`Pack` of a dictionary row throws `ArgumentException` naming the member" (AZ-2191 Description) → Given an `int` for a `Bytes`/`Sized` name When packed, in or outside a round Then `ArgumentException` naming the member | batch_02 #8 |
| D2 | a non-null typed nested row whose members are all null leaves a flags group's bit clear (object dropped silently) | gap-unclear | question below | batch_01 #2 |
| D4 | collection members that are not `E[]`, `List<E>`, `Dictionary<string,E>` (for example `Stack<int>`) throw `InvalidCastException` at unpack | gap-unclear | question below | batch_01 #4 |
| D8 | `Expression.Compile` per field under trimming, AOT, IL2CPP | gap-unclear | question below | batch_01 #8 |
| D11 | AZ-2092 AC-7: the typed round trip is 2.0x (cold) / 2.6x (warm) faster, not 3x | gap-unclear | question below | batch_01 #11 |
| E4 | a `Flags` container as a direct list or dict element throws `KeyNotFoundException` in `Read` | gap-unclear | question below | batch_02 #4 |
| E5 | a lone dictionary for a `Dict` name in a round is broadcast (it threw before); a lone `string` for `Utf8` broadcasts | gap-unclear | question below | batch_02 #5 |
| E9 | char, enum and `object` values for numeric fields are refused (`'a'` and `DayOfWeek` used to convert) | gap-unclear | question below | batch_02 #9 |
| E11 | `u2` slots, `bits` and `packed` items still round or coerce (a `1.5` in a `u2` slot packs as 2) | gap-unclear | question below | batch_02 #11 |

### Gaps that need a decision (gap-unclear)

#### D2: an object that is present but empty

**What is not decided**
A nested row object under a flags group is non-null but every member is null. Today the group's bit stays clear and the whole object disappears from the packet without an error; a set group with a null nested row fails loudly. The specs say "any value is present" but do not say whether the object itself counts.

**Options**
- **A — keep today's silent drop**: an all-null object is the same as no object. Trade-off: the caller gets no error for data that was handed in.
- **B — a non-null object counts as present**: the bit is set and pack fails naming the first missing member. Trade-off: stricter; a caller that builds empty placeholder objects starts to get errors.

**Recommendation**: B, because every other loud-pack rule of loops 11 to 17 turns silent drops into errors (owner reason on AZ-2181: refusing can be relaxed later, accepting cannot be withdrawn).

#### D4: unsupported collection members in a typed row

**What is not decided**
A typed row member of a type that is not an array, `List<E>` or `Dictionary<string,E>` (for example `Stack<int>`) builds and throws `InvalidCastException` when unpacking, as it did before this loop. The spec asks only for row types to be checked at construction.

**Options**
- **A — refuse at scheme construction** with an `ArgumentException` naming the member. Trade-off: breaks nobody who unpacks (it already throws) but breaks schemes that only pack.
- **B — leave as is**.

**Recommendation**: A, one line plus a test, same family as the other construction checks.

#### D8: AOT and IL2CPP

**What is not decided**
Every field now compiles two delegates when it is built. The README says Unity IL2CPP is supported. Under IL2CPP the compiled expressions run through the interpreter: the result should be the same but slower. Nothing was run on Unity here.

**Options**
- **A — add one README sentence and run the suite once under a Unity IL2CPP test project** before the next release.
- **B — add the sentence only**, no run.
- **C — nothing**.

**Recommendation**: B for now; A before a release that advertises Unity.

#### D11: the typed path is 2x faster, the spec asked for 3x

**What is not decided**
AZ-2092 AC-7 asked for at least 3x and 300 ms for 100 000 round trips. Measured: Debug AC-10 test 791 ms to 274 to 284 ms; Release test run 641 to 656 ms to 304 to 348 ms; standalone Release cold pass about 570 ms to 267 to 278 ms (2.0x), warmed 150 ms to 57 ms (2.6x). The project limit (AC-10, 1 s) has about 3x margin. Going lower needs a typed walker that does not go through a dictionary (the engine alone costs 130 ms cold), which breaks "one canonical walker".

**Options**
- **A — accept** and amend AC-7 to the measured numbers.
- **B — spec a dictionary-free typed walker** (5 points or more).

**Recommendation**: A: the project bound holds with margin and a second walker adds the parallel-pipeline cost the coding rules warn about.

#### E4: a `Flags` container as a list or dict element

**What is not decided**
C# throws `KeyNotFoundException` in `Read` for a list or dict whose element is a `Flags` container; TypeScript, Python and Java accept it (the `listflags` ring shape; C# does not take part in that ring).

**Options**
- **A — support it** (reuse `ElementValue`, typed side too), so the same scheme gives the same bytes in every language, and add C# to the ring.
- **B — refuse at construction** with a clear message and document it.
- **C — leave it**.

**Recommendation**: A, for the same-bytes rule.

#### E5: a lone dictionary or string in a round

**What is not decided**
In a `repeat`/`times` round a lone `IDictionary` for a `Dict` name is broadcast to every round (it threw before), and a lone `string` for a `Utf8` name broadcasts, as in the other packages. A lone `IList` for a `List` name stays "a list of rounds". AZ-2182 asked whether the loud error covers `List` and `Dict` names; its ACs name only `Bytes`, `Sized`, `Bits`, `Packed`.

**Options**
- **A — a lone dictionary is refused like a lone collection** (a dict value belongs in a list with one entry per round).
- **B — keep the broadcast** (a dictionary is a scalar-like value in a round).

**Recommendation**: A for symmetry with the lone-collection rule; check what TypeScript, Python and Java do first (not probed here).

#### E9: char, enum and object for numeric fields

**What is not decided**
Dictionary rows used to convert a `char` (`'a'` became 97) or an enum (its number) for an integer field through `IConvertible`. The specs refuse bool, string and fractions only; the implementation refuses these too.

**Options**
- **A — keep the refusal** (and say so in the upgrade note).
- **B — accept an enum through its underlying integer** and keep refusing `char` and `object`.

**Recommendation**: A: the other packages have no enum or char types, so the same-bytes rule does not need them.

#### E11: `u2` slots, `bits` and `packed` items still coerce

**What is not decided**
A `1.5` in a `u2` slot packs as 2; `bits` and `packed` items convert with rounding. AZ-2191 left them out and flagged "include here or follow-up" as the owner's.

**Options**
- **A — follow-up spec** (about 1 point): the same strict rule for every slot.
- **B — leave the rounding** and document it.

**Recommendation**: A, one rule for every numeric slot.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| E3 | Given the rows `Read` returns for a list or dict of group elements, When they are passed to dictionary `Pack`, Then the same bytes come out and no `'A' has no value` | "the value shape matches what the other five packages return for the same scheme" (`AZ-2119_csharp_group_list_element.md` AC-1) | new C# spec, about 1 point |
| E6 | Given a Rust map scheme with `times` and a lone scalar, When packed, Then every round carries the scalar | "option A: broadcast a lone scalar to every round, refuse a lone collection" (`AZ-2182_csharp_nonlist_round_value.md` Owner decision) | new Rust spec (no ticket yet), about 1 to 2 points |
| E8 | Given an `int` for a `Bytes` or `Sized` name, When packed in or outside a round, Then `ArgumentException` naming the member | "`Pack` of a dictionary row throws `ArgumentException` naming the member" (`AZ-2191_csharp_dict_pack_strict.md` Description) | new C# spec, 1 point |

### Not walked

- Typed `Pack`/`Unpack` of one shared scheme from several threads: the new files keep no shared mutable state (statics are factories and read-only tables) and no new thread test exists; one small test would pin it.
- A typed row whose nested type is a `struct` or has only a non-public constructor (`FieldBinding.Creator` requires a public parameterless constructor; a `struct` with a default constructor is not probed).
- `init`-only members and records in typed rows (the member-kind test covers a public field and a private setter only).

### Harness gaps

- none: both batch reports carry `## Discovered during implementation`; no `scenarios.md`, `problem.md` or `implementation_report_*_loop17.md` exists yet for this loop (the specs predate the scenario matrix).
