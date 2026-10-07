# Flag group presence counts every child kind at any depth (C#, Java, Rust)

**Task**: AZ-2128_flag_group_presence_parity
**Name**: Flag group presence parity
**Description**: A flags group's bit is on when any value inside it, at any depth and of any kind, is present; nothing is dropped silently.
**Complexity**: 3 points
**Dependencies**: AZ-2079, AZ-2082, AZ-2089
**Component**: csharp, java, rust, typescript, python
**Tracker**: AZ-2128
**Epic**: AZ-2069

## Problem

Found by the loop 12 re-reviews. A flags group whose only present values sit in child kinds the presence check ignores never sets its bit, so the values are dropped without an error:

| Package | Ignored child kinds | Probe |
|---------|---------------------|-------|
| C# | nested `Flags`, split `FlagBit`, `When`, `Repeat`, `Times` | `Flags(0, Group(0, Mark, Flags(0, U8 B)))`, B=5 → `0100` |
| Java | the same, plus `u2` (`childOn` has no U2 case) | `flags(0, u2(a, b))`, `{a:1, b:2}` → `0100` |
| TypeScript | `u2`, `bits`, `sized`, `packed` (`kinds.ts` `scalarChildNames`) | u2-only group `{p:1,q:2}` → `0100`; anchored bits-only `n=8` → `010800`; sized-only → `010100` |
| Python | `u2` (`_pack.py` `_child_on`) | u2-only group `{p:1,q:2}` → `0100` (bits OK) |
| Rust (map API) | `u2`, `sized`, `bits`, `packed`, nested group, nested `flags`, `when` (`group_on`) | u2-only group under flags → `0100` |

C++ `present()` recurses into nested groups. C# already counts u2/sized/bits/packed and nested groups (AZ-2079 AC-7, loop 12).

## Outcome

- The group's bit is on when any value inside it, at any depth, is present.
- Where a set group cannot be written in full, pack fails loudly naming the missing value (as C# does since AZ-2079 F1).

## Acceptance Criteria

**AC-1**: each probe above sets the bit and round-trips, in its package.
**AC-2**: a group whose nested container has a value but whose sibling required value is null fails pack naming that value.
**AC-3**: golden and route fixtures unchanged.

## Constraints

- ADR-001: each package implements it itself. Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loop 12 (AZ-2133 discovery, Rust map): a `times` or `when` as a `flags` member or flag-bit field is never written, no error (`member_on` finds no name): `flags(1,"f",[times(1,"0",[u8 "1"])])` with `0=1`, `1=[5]` → `010100`; same for `when`. Refuse at construction or define their presence here | coordinator | open | Medium |
| Written from review findings; refine before the loop that takes it. TypeScript and Python added from loop 12 assessment G6 | coordinator | open | Low |
| Loop 13 assessment (T25, T26, R24): TypeScript flat unpacked rows of a group under flags whose only members are flags/u2/sized/bits/packed/nested group leave the group bit clear and do not repack (`{n:5}` → `0100`; the nested form `{g:{n:5}}` works); a `when` or `times` as a `flags` member never sets its bit in TypeScript (`k:1 v:9` packs `01 01 00`) and Rust (typed `times` Vec form now reaches it: n = 1, pts = [5] packs `01 01 00`). Decide: refuse at construction or define their presence | coordinator | open | Medium |

## Loop 16 progress (2026-10-06)

| Part | Package | State |
|------|---------|-------|
| AC-1 to AC-3 (u2, sized, bits, packed, nested group and nested flags count; a set group lacking a required value fails naming it) | TypeScript | done in batch 2 (`flag-bits.ts`, `bitOn` recursion) |
| same | Rust (map API) | done in batch 2 (`group_on` / `member_on`) |
| same | Java | done in batch 2 (`Walker.childOn` FLAGS and U2 cases) |
| same | Python | done in batch 2 (u2 and nested flags presence) |
| same | C# | done in loop 17 batch 1 for nested `Flags` and split `FlagBit` children (`Walker.Presence.cs`; B=5 gives `01 01 01 05`, AC-2 fails naming the missing value); a direct `u2` member with only a non-first slot present is still dropped (fixed in batch 2) |
| flagged concern: `when`, `times`, `repeat` as a `flags` member or flag-bit field | all | NOT implemented or refused. Owner decision 2026-10-06: hold for the loop that lands the C# work, so the five packages are decided together (today they all give the same bytes for the AZ-2120 shape, `01 01 02 5a00`; AZ-2120 will make C# `01 01 03 07 5a00` and requires the other five to match) |
