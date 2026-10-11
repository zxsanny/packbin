---
loop: 19
branch: dev
---

# In Python, each `repeat`/`times` round starts with a fresh `seen` scope, as TypeScript and C# do, in pack and unpack

**Task**: AZ-2330_python_round_fresh_scope
**Name**: Python fresh scope per round
**Description**: In Python, each `repeat`/`times` round starts with a fresh `seen` scope, as TypeScript and C# do, in pack and unpack.
**Complexity**: 2 points
**Dependencies**: None
**Component**: python
**Tracker**: AZ-2330
**Epic**: AZ-2069

## Problem

Owner decision 2 (review T1) of loop 19 (2026-10-11, option A, accepted as recommended). Python rounds reuse the outer `seen`, so a value a round skipped stays visible to a later `when`: the same row packs `01020105010002` in Python and `010201050100` in TypeScript.

## Outcome

- Python packs and unpacks that row to `010201050100`.
- The other rows of the golden, route and ring fixtures are unchanged.

## Scope

### Included
- Fresh scope per round in Python pack and unpack.
- Upgrade note: Python bytes change for a round whose `when` names a value an earlier round skipped.

### Excluded
- TypeScript, C#, Java, Rust, C++ (probe table in the batch report only).

## Acceptance Criteria

**AC-1: round scope is fresh**
Given the loop 18 review T1 row with a `when` after a skipped value in an earlier round
When packed by Python
Then `010201050100`, equal to TypeScript

**AC-2: unpack mirrors it**
Given the same bytes
When unpacked by Python
Then the same row as TypeScript returns

**AC-3: other fixtures unchanged**
Given golden, route and ring fixtures
When Python suite run
Then all pass without edits

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | T1 row pack | `010201050100` |
| AC-2 | T1 bytes unpack | row equals TypeScript |
| AC-3 | existing suite | passes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | T1 row, Python and TypeScript | differential pack | identical hex | — |

## Constraints

- Differential rule of LESSONS.md: one hostile value outside the member's range.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Python bytes change for that shape (upgrade note) | owner decision 2, 2026-10-11 | resolved | Medium |
