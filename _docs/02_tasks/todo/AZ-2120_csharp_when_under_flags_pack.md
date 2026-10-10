---
loop: 18
branch: dev
---

# C# pack drops a When directly under a combined Flags group

**Task**: AZ-2120_csharp_when_under_flags_pack
**Name**: C# pack drops a When directly under a combined Flags group
**Description**: `FlagGroup.Compute` checks `IsPresent(values, "")` for a `When`, so its bit stays clear and its field is not written on pack: `Mode=1, Speed=7, Heading=90` packs to `0101025a00` and drops `Speed`, while unpack of `01 01 03 07 5a00` is correct.
**Complexity**: 2 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2120
**Epic**: AZ-2069

## Problem

`FlagGroup.Compute` checks `IsPresent(values, "")` for a `When`, so its bit stays clear and its field is not written on pack: `Mode=1, Speed=7, Heading=90` packs to `0101025a00` and drops `Speed`, while unpack of `01 01 03 07 5a00` is correct. Pack and unpack disagree. Found in loop 11 round 2; it predates the loop.

## Outcome

Each AC below passes; wire bytes of packets that work today do not change.

## Scope

### Included
- csharp: the change and tests named in the ACs.

### Excluded
- Error kind and label of any error value (C15).

## Acceptance Criteria

**AC-1**
Given a combined `Flags(...)` containing a `When` on Mode, When `Mode=1, Speed=7, Heading=90` is packed, Then the bytes are `01 01 03 07 5a00` and unpack returns the same row

**AC-2**
Given the other five packages, When the same scheme is packed, Then the bytes match C#

## Constraints

- ADR-001: no shared walker, no import from another package.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: scope creep. *Mitigation*: Make Compute treat a When like a Group; check the other packages for the same shape. Source: loop 11 round 2 C# worker.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Written from a worker discovery; refine the Given/When/Then before the loop that takes it | coordinator | open | Low |

## Loop 18 decision and acceptance criteria (owner 2026-10-10, option A: all six packages write them)

Scope widens from C# to all six packages (typescript, python, rust, java, cpp, csharp) and from `when` to `when`, `times` and `repeat` as a `flags` member or a flag-bit field (also AZ-2128 flagged concern). Reference: the C# unpack of `01 01 03 07 5a00` is correct today and is the reading every package must match.

Rule: a `when`, `times` or `repeat` that is a member of a `flags` container (or inside a group or flag-bit field under it) is a value like any other: its bit is on exactly when it writes a value (a `when` whose condition holds and whose body holds a value; a `times` or `repeat` with at least one round), and on unpack a set bit reads the body. Where a set member cannot be written in full, pack fails loudly naming the missing value (AZ-2128 AC-2). Wire bytes of every packet that does not use this shape do not change; the old bytes of the shape (`01 01 02 5a00`, bit clear, `Speed` dropped) are no longer written.

**AC-3: `when` under `flags`, all six**
Given a combined `flags` holding a `when` on `Mode` (body `Speed`) and a `Heading` field, and the row `Mode=1, Speed=7, Heading=90`
When packed and unpacked in each package
Then the bytes are `01 01 03 07 5a00` and unpack returns the same row; with `Mode=0` (condition false, no `Speed`) the `when` bit is clear and the row round-trips

**AC-4: `times` and `repeat` under `flags`, all six**
Given the same shape with a `times` (and, where the package has it, `repeat`) member holding one value per round
When packed with one or more rounds, and with zero rounds
Then the bit is on exactly when a round is written; the bytes are the same in every package (each package derives them from a run of C# or TypeScript first) and the row round-trips

**AC-5: cross-package packets**
Given the packets of AC-3 and AC-4 written by one package
When every other package unpacks them
Then the rows are equal (checked by each package against the pinned hex)

**AC-6: nothing else changes**
Given golden, route and every existing test
When the suites run
Then bytes and results are unchanged except the tests that pinned the old dropped-value bytes

## Flagged concerns (loop 18)

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Behavior change in five packages that agreed on the old bytes (`01 01 02 5a00`); upgrade note | owner decision 2026-10-10 | resolved | Medium |
| The exact schemes and bytes for `times` and `repeat` are derived from runs by the wave 3 workers; if the packages cannot agree on one reading, the worker stops and reports | coordinator | open | Medium |
