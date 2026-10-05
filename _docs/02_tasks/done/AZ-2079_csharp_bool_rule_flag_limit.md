---
loop: 12
---

# C# bool rule and the 8-bit flags limit

**Task**: AZ-2079_csharp_bool_rule_flag_limit
**Name**: C# bool presence and 9th flag bit
**Description**: A C# `bool` sets its flag bit only for `true` and exists only as a flag bit; a 9th bit in one flags byte fails construction.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors (construct vectors), AZ-2076_csharp_unpack_state_per_call (both change `FlagGroup` in `csharp/Walker.cs`)
**Component**: csharp
**Tracker**: AZ-2079
**Epic**: AZ-2069

## Problem

### Defect 1 — `bool false` sets the bit; C# and Java disagree on the bytes (project AC-3)
- `csharp/Walker.cs:21-34` `FlagGroup.Compute` sets a bit when `Walker.IsPresent(values, inner.Name)` is true (line 29). `IsPresent` (`:39-40`) means "key present and not null", so a non-nullable `bool` that is `false` counts as present.
- `Walker.cs:152-163` `UnpackBool` always stores `true` when its bit is set.
- Probe (copy of sources at `d108141`): `new Scheme<BoolRow>(1, Field.Flags(0, Field.Bool<BoolRow>(0, x => x.Straight)))` with `BoolRow { bool Straight; }`.
  - `Pack(new BoolRow { Straight = false })` → C# **`01 01`**; Java and Python give `01 00` for the same row; TypeScript gives `01 01` (task 11).
  - Unpack of C#'s own bytes → `Straight = true`. **`false` comes back `true`.**
- The empty continuing group used as a presence mark behaves the same: `Field.Flags(0, Field.Group(0, (MarkRow x) => x.Mark))` with `bool? Mark = false` packs **`01 01`** (presence through `Walker.GroupOn`, `:42-52`), and unpack stores `true` (`:328-329`).

### Defect 2 — `bool` / empty group outside flags are accepted and do not round-trip
- `Field.Bool<T>` (`Field.cs:120-124`) can be placed anywhere. At top level `PackBool` (`Walker.cs:145-150`) writes **0 bytes**. Unpack (`:152-163`) **always stores `true`**.
  - Probe: `new Scheme<BoolRow>(1, Field.Bool<BoolRow>(0, x => x.Straight))`, `Straight = false` → packs `01`; unpack of `01` → `Straight = true`.
- `Field.Group(0, (MarkRow x) => x.Mark)` at top level (`Field.cs:193-199`, no children) constructs; `Mark = true` packs `01`; unpack stores `true` whatever was packed.
- README defines `bool` as "a flag bit with no payload" (`README.md:630`). Java stores nothing; C++ stores `true`; Rust drops it.

### Defect 3 — a 9th flag bit is silently dropped
- `FlagGroup.AddBit` (`Walker.cs:14-19`) has no limit. `Compute` builds the byte with `(byte)(1 << i)` (line 31), so bit 8 becomes `0`. `PackFlags` (`:165-175`) then skips that child.
- Probe: `Flags(0, U8 A0 … U8 A8)` (9 children), row `{ A8 = 5 }` → **`01 00`**; the 5 is gone, no error.
- Same through the split form: 9 calls of `m.Bit(...)` on one `Field.FlagByte()`.
- Java rejects the 9th bit at construction (`Field.java:329`, "flags already has 8 bits"); so does C++.

### Related presence gap (S32)
- `Walker.GroupOn` (`:42-52`) looks only at children that pass `IsScalarOrBytes` (`:54-56`). A flag group whose only children are `Sized`, `Bits`, `Packed` or `U2` never sets its bit, and their values are dropped. Java's `childOn` (`Walker.java:26-35`) covers Sized/Bits/Packed.

## Outcome

User decision 2026-10-05, verbatim: **"The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error."**

- C# produces `01 00` for `Straight = false`, matching Java and Python. `false` and `null` round-trip as not-`true`.
- `bool` or an empty group outside a flags bit fails `Scheme<T>` construction with `ArgumentException`.
- A 9th bit on one flags byte fails construction with `ArgumentException`.
- A flag group's bit is set when any value-bearing child is present, whatever its kind.

## Scope

### Included
- Bit computation for `bool` and empty groups, in both `Flags` and the split form `FlagByte`/`.Bit`.
- Construction checks: bool/empty-group placement and the 8-bit limit, in the `SchemeOrder` walk and/or in `FlagGroup.AddBit`.
- Group presence for all value-bearing child kinds.
- A cross-language case for `bool false` in the language-pair vectors, coordinated with tasks 11/14 so all packages expect `01 00`.

### Excluded
- Null required values outside flags (task 19).
- Forward references (task 18).
- TypeScript, Python, Rust, C++ and Java bool fixes (tasks 11–14, 20).

## Acceptance Criteria

**AC-1: false clears the bit**
Given `Flags(0, Bool Straight)` and a row with `Straight = false`
When packed
Then the bytes are `01 00`, and unpack gives `Straight = false`.

**AC-2: true sets the bit, null clears it**
Given the same scheme
When `Straight = true` (bool) is packed, and separately `null` (`bool?`)
Then `01 01` round-trips to `true`, and `01 00` round-trips to `null`.

**AC-3: Empty group follows the same rule**
Given `Flags(0, Group(0, x => x.Mark))` with `bool? Mark`
When `Mark` is `false`, `null` and `true`
Then the flag bytes are `00`, `00` and `01`.

**AC-4: bool outside flags is a construction error**
Given `Field.Bool` as a top-level field, inside `When`, `Repeat`, `Times`, a list/dict element or a nested group (not as a direct flag bit)
When `new Scheme<T>(…)` runs
Then it throws `ArgumentException`, 0 schemes are built and 0 bytes are written.

**AC-5: Empty group outside flags is a construction error**
Given `Field.Group(0, x => x.Mark)` with no children outside a flags bit
When the scheme is built
Then `ArgumentException`.

**AC-6: Ninth bit is a construction error**
Given 9 children in one `Flags`, or 9 `.Bit(...)` calls on one `FlagByte()`
When the scheme is built (or the 9th bit is added)
Then `ArgumentException` naming the limit of 8. Nothing is silently dropped.

**AC-7: Group bit sees every child kind**
Given a flags bit that is a continuing group whose only value-bearing children are of kind `U2`, `Bits`, `Sized` or `Packed` (count = an earlier field before the flags, e.g. `U8 N` at id 0), with those children's values present and the group's own member `null`
When packed
Then the bit is set and the children are written. Unpack round-trips. Today the bit stays clear and the values are dropped.

**AC-8: Existing bytes unchanged**
Given the golden fixture, the route fixture `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` (its `Straight` bit is set for `true`) and `FieldIdBindingTests` (`Hidden = true`, `Delta = null`)
When the suite runs
Then all pass with identical bytes.

## Non-Functional Requirements

**Compatibility**
- The only intended wire change: a `bool false` or empty-group `false` now packs a clear bit instead of a set bit. This matches Java and Python. Record it in the release notes.

## Unit Tests

Write these first; AC-1, AC-3, AC-4, AC-5, AC-6 must fail on the current code.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | probe `Flags(0, Bool Straight)`, `Straight = false` | `0100`; round-trip `false` |
| AC-2 | `Straight = true`; `bool? = null` | `0101` → `true`; `0100` → `null` |
| AC-3 | empty group `Mark` false / null / true | `0100` / `0100` / `0101` |
| AC-4 | `new Scheme<BoolRow>(1, Field.Bool<BoolRow>(0, x => x.Straight))` | `ArgumentException` |
| AC-4 | `Repeat(0, Bool(0, …))`, `When(1, Eq(0,…), Bool(1, …))` | `ArgumentException` each |
| AC-5 | top-level `Field.Group(0, (MarkRow x) => x.Mark)` | `ArgumentException` |
| AC-6 | 9-child `Flags` (probe row `A0..A8`) | `ArgumentException`, no bytes |
| AC-6 | `FlagByte()` + 9 `.Bit` | `ArgumentException` on the 9th |
| AC-7 | `U8 N` (id 0), then `Flags(1, Group(1, x => x.Mark, Bits(1, x => x.Segs, 0)))`, `N = 8`, `Segs` = eight 1s, `Mark = null` | flags `01`, then `ff`; today flags `00` and `Segs` dropped |
| AC-8 | `BorrowedCountTests.Route_*`, `FieldIdBindingTests.*`, `LayoutTests.FlagGroup_*` | pass unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/hostile/` construct vector `nine_flag_bits` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-6 | `fixtures/hostile/` construct vector `nine_flag_bits_split` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-4 | `fixtures/hostile/` construct vector `bool_outside_flags` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-5 | `fixtures/hostile/` construct vector `empty_group_outside_flags` | C# suite builds the scheme it describes | `scheme_error` (construction throws), 0 schemes | — |
| AC-1 | language-pair vector "bool false in flags" (added with tasks 11/14) | C# packs, every other language unpacks, and back | identical `0100`, value `false` everywhere | AC-3 (project) |
| AC-8 | `fixtures/golden.hex` | pack/unpack | identical | AC-1/AC-2 |

## Constraints

- ADR-001: the rule is implemented in C# itself. Other packages have their own tasks.
- Wire bytes change only for `bool false` / empty-group `false` in flags (the decided fix). Every golden vector stays green.
- Construction errors keep the existing type (`ArgumentException`), consistent with `SchemeOrder`.

## Risks & Mitigation

**Risk 1: Callers relying on `bool` as a top-level field**
- *Risk*: it never round-tripped (always unpacked as `true`), so any user of it already had broken data.
- *Mitigation*: fail at construction with a message that points to `Flags`.

**Risk 2: Peer on an older C# version**
- *Risk*: an old C# peer sends `bit set` for `false`; a new peer reads `true`. That is unchanged behavior on the old side.
- *Mitigation*: release note: mixed C# versions disagree on `bool false` until both sides upgrade.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Wire change for `bool false` (`0101` → `0100`) between C# 0.1.x and the next release. | user decision 2026-10-05 | accepted-risk | Medium |
| Whether a bool may be a child of a group that is itself a flag bit. This spec allows only a direct flag bit; confirm with C++ (task 12) so all packages agree. | tasks 11–14 owners | open | Low |
