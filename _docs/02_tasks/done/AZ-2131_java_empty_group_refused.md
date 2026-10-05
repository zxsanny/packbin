---
loop: 12
---

# Java refuses empty groups that can never set their bit; pin non-true bool values

**Task**: AZ-2131_java_empty_group_refused
**Name**: Java empty group refused
**Description**: An empty group that can never carry `true` fails scheme construction wherever it stands; a map bool value other than `Boolean.TRUE` is pinned to a clear bit; the Java driver joins the `bitwhen` ring.
**Complexity**: 2 points
**Dependencies**: AZ-2089_java_forward_refs_bool
**Component**: java
**Tracker**: AZ-2131
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` U3, G3, U4).

- **U3**: `group(anchor)` with no fields has no accessor, so inside `flags` it builds but its bit is always clear (AZ-2089 flagged concern). The test "AC-6 empty group in flags" (`BoolPlacementTest.emptyGroupAsFlagBitStillBuilds`) asserts it builds.
- **G3**: a map value `1` or `"true"` for a bool packs `0100`; no test pins it.
- **U4**: Cross-language `bitwhen` vector (owner decision U4, 2026-10-05): scheme type 1 = `u8 k` (id 0), split flag byte `m`, `when(eq(k, 1), [m.bit(u8 v)])`. Row `{k:0, v:5}` packs `010001` (the bit is set from the row even though the `when` is not taken; unpack checks the `when` first and never reads it); row `{k:1, v:5}` packs `01010105`. Driver contract: `pack-bitwhen` prints the hex of `{k:0, v:5}`; `unpack-bitwhen <hex>` exits 0 only if unpack is ok, `k == 0` and `v` is absent.

## Owner decisions (2026-10-05)

U3: A — any empty group that can never carry `true` fails construction wherever it stands (the "AC-6 empty group in flags" case flips). An empty nested row `group(get, set)` under a flag bit stays allowed only if its bit can be set from the row (test it); otherwise it is refused too. U4: A.

## Acceptance Criteria

**AC-1: accessor-less empty group refused everywhere**
Given `group(anchor)` with no fields at top level, directly in `flags`, and as a `flagByte().bit(...)`
When the scheme is built
Then `IllegalArgumentException` naming the group

**AC-2: empty nested row**
Given an empty nested row `group(get, set)` under a flag bit
When a row with a present / absent member is packed and unpacked
Then it round-trips presence (bit set / clear), or, if it cannot, construction fails like AC-1

**AC-3: non-true map values clear the bit**
Given `flags(0, boolField(0, on))`
When `on = 1` and `on = "true"` are packed
Then `0100`

**AC-4: bitwhen vector**
Given the `bitwhen` scheme
When `{k:0, v:5}` and `{k:1, v:5}` are packed and unpacked
Then `010001` and `01010105`; `Handoff.java` implements `pack-bitwhen` / `unpack-bitwhen`

## Constraints

- ADR-001; files ≤ 500 lines; `IllegalArgumentException` for construction errors.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| AC-2 holds for Map rows; a typed empty nested row hits AZ-2101 Defect 1 (`ClassCastException` on unpack), like every typed nested row | owner 2026-10-05: accept the AZ-2101 dependency | accepted-risk | Medium |
