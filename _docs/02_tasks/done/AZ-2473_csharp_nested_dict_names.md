---
loop: 25
branch: dev
---

# C# dictionary rows read nested-row group's names from the nested dictionary

**Task**: AZ-2473_csharp_nested_dict_names
**Name**: C# dictionary rows read nested-row group's names from the nested dictionary
**Description**: A dictionary row holding a nested-row group reads the group's member names from the inner dictionary of that row, not from the outer dictionary. Breaking: a flat row that provided those names at the outer level stops working.
**Complexity**: 2 points
**Dependencies**: none
**Component**: csharp
**Tracker**: AZ-2473
**Epic**:

## Problem

C# today looks up a nested-row group's members on the outer dictionary; U26 A (handoff 25) chooses the parity-correct behavior: the group reads its members from the nested dictionary of its outer row, matching GO-12 ("The map form reads a nested-row group from the nested map"), the TypeScript Dict reader and the memory `one-total-review-and-test` loop 22 parity table rows.

Reference: `_docs/02_task_plans/strings-lists-dicts/` (U26 row), GO-12 above, loop 24 handoff D-batch 2026-10-13 (U26 A decided).

## Outcome

- Packing a dictionary row with a nested-row group reads the group's member names from the inner dictionary; the packed bytes match TypeScript's for every parity row that exercises this.
- A flat row that previously provided those names at the outer level fails with `BadValue` naming the missing nested dictionary and the field id of the nested-row group.
- No touch to any other package; the parity table rows that pin this read the C# bytes and match TypeScript.

## Scope

### Included

- `csharp/src/*` edits that select the dictionary for a nested-row group.
- `csharp/tests/` tests pinning every row in `## Blackbox Tests`.
- Owns (exclusive write): `csharp/src/**`, `csharp/tests/**`

### Excluded

- Any other package.
- Any `_docs/02_task_plans/**` wording change (parent writes the parity row text at close if needed).

## Acceptance Criteria

**AC-1: Nested-row group reads nested dictionary**
Given a dictionary row `{ "g": { "n": 7 }, "x": 1 }` built with `dict(group("g", u8(0,"n")), u8(1,"x"))`
When packed in C#
Then the bytes match TypeScript (the "n" count comes from the nested dictionary, the "x" from the outer), with 0 mismatched bytes.

**AC-2: Flat row with names at outer level fails**
Given a dictionary row `{ "g": {}, "n": 7, "x": 1 }` for the same scheme (names flat at outer)
When packed in C#
Then the pack returns `BadValue` naming the missing nested dictionary and the group's field id; written bytes 0.

**AC-3: Unpack matches TypeScript**
Given the packed bytes of AC-1
When unpacked in C#
Then the dictionary round-trips with the nested group holding `n=7`; mismatched fields 0.

**AC-4: Parity rows pin the behavior**
Given the dictionary parity rows (TypeScript's U26 and related)
When run in C#
Then hex mismatches 0; refusal-vs-bytes disagreements 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | pack the nested-dictionary row | bytes match TypeScript |
| AC-2 | pack the flat row | `BadValue` names the missing nested dictionary |
| AC-3 | unpack the AC-1 bytes | round-trips |
| AC-4 | the parity table rows | hex mismatches 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `{ "g": { "n": 7 }, "x": 1 }` with `dict(group("g", u8(0,"n")), u8(1,"x"))` | pack | TypeScript bytes | |
| AC-2 | same scheme, flat `{ "g": {}, "n": 7, "x": 1 }` | pack | `BadValue` | |
| AC-3 | AC-1 bytes | unpack | round-trip equal | |
