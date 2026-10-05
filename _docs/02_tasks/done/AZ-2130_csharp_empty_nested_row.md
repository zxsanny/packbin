---
loop: 12
---

# C# refuses an empty nested-row group; pin non-true bool values

**Task**: AZ-2130_csharp_empty_nested_row
**Name**: C# empty nested-row group
**Description**: A zero-child nested-row group fails scheme construction wherever it stands; a dictionary bool value other than `true` is pinned to a clear bit; the C# driver joins the `bitwhen` ring.
**Complexity**: 2 points
**Dependencies**: AZ-2079_csharp_bool_rule_flag_limit
**Component**: csharp
**Tracker**: AZ-2130
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` U3, G3, U4).

- **U3**: `Field.Group((Q x) => x.Nested)` with no children binds an object, so `IsTrue` is never true: inside `Flags` it builds but its bit is always clear (`Nested = new In()` packs `0100`; unpack of `0101` leaves `Nested` null). At top level it is refused with the bool message, which is misleading.
- **G3**: a dictionary value `1` or `"true"` for a bool packs `0100`; no test pins it.
- **U4**: Cross-language `bitwhen` vector (owner decision U4, 2026-10-05): scheme type 1 = `u8 k` (id 0), split flag byte `m`, `when(eq(k, 1), [m.bit(u8 v)])`. Row `{k:0, v:5}` packs `010001` (the bit is set from the row even though the `when` is not taken; unpack checks the `when` first and never reads it); row `{k:1, v:5}` packs `01010105`. Driver contract: `pack-bitwhen` prints the hex of `{k:0, v:5}`; `unpack-bitwhen <hex>` exits 0 only if unpack is ok, `k == 0` and `v` is absent.

## Owner decisions (2026-10-05)

U3: A — any empty group that can never carry `true` fails construction wherever it stands. An empty group whose member is a `bool` / `bool?` stays a presence bit. U4: A.

## Acceptance Criteria

**AC-1: empty nested-row group refused everywhere**
Given a zero-child nested-row group at top level, directly under `Flags`, and under a `FlagByte` bit
When the scheme is built
Then `ArgumentException` with a message of its own naming the group (not the bool message)

**AC-2: bool empty group unchanged**
Given `Flags(0, Group(0, x => x.Mark))` with `bool? Mark`
When `true` / `false` / `null` are packed
Then `0101` / `0100` / `0100` as today

**AC-3: non-true dictionary values clear the bit**
Given `Flags(0, Bool On)` packed from a dictionary
When `On = 1` and `On = "true"`
Then `0100`

**AC-4: bitwhen vector**
Given the `bitwhen` scheme
When `{k:0, v:5}` and `{k:1, v:5}` are packed and unpacked
Then `010001` and `01010105`; the driver implements `pack-bitwhen` / `unpack-bitwhen`

## Constraints

- ADR-001; files ≤ 500 lines; `ArgumentException` for construction errors.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | — | — |
