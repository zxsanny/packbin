---
loop: 23
branch: dev
---

# No-value count refusal (U11) pinned inside groups, nested whens and round bodies

**Task**: AZ-2436_no_value_count_nested_positions
**Name**: No-value count refusal (U11) pinned inside groups, nested whens and round bodies (G3)
**Description**: The U11 refusal is pinned only at the top level; add standing tests for nested positions in every package that can spell them.
**Complexity**: 2 points
**Dependencies**: AZ-2434 (TypeScript, same worker)
**Component**: typescript, python, java, csharp, rust, cpp (tests only)
**Tracker**: AZ-2436
**Epic**: AZ-2069

## Problem

Assessment22 gap G3. AZ-2410 (U11) refuses a `bits`/`packed`/`sized` count above 0 behind a clear `when` with no value when no field wrote the count. The refusal code walks groups and holding `when`s, but tests pin only the top level of a scheme (`reference_loop22.md` row 56). TypeScript and Python probes in loop 22 found the same refusal inside a `times` round.

## Outcome

- In each package that can spell it: the counted member inside a group, behind a nested holding `when` (outer holds, inner clear), and in a `times`/`repeat` round body is refused with the U11 message naming member and count.
- Count 0, a left-out count and a holding inner `when` still pack, hex as at HEAD.
- A package that cannot spell a position says so in its test file comment and the batch report; a package that packs where the rule says refuse is reported to the parent and not changed here (D3).

## Scope

### Included
- One test file per package directory.

### Excluded
- Source changes.

## Acceptance Criteria

**AC-1: group**
Given the row 56 shape inside a group
When packed with count 3 and no value
Then refused, member and count named.

**AC-2: nested holding when**
Given the row 56 shape (count source skipped by a clear `when`, counted member outside that `when`) placed inside an outer `when` that holds (also as a bit holding a holding `when` around the member)
When packed with count 3 and no value
Then refused.
(Amended 2026-10-13 after the TypeScript worker's probe: a counted member *inside* the clear `when` is the existing silent skip, not the U11 rule; pin that literal shape as "observed, silent skip" where a package can spell it.)

**AC-3: round body**
Given the shape inside a `times` and a `repeat` round
When packed with count 3 and no value in one round
Then refused.

**AC-4: unchanged**
Given count 0, left out, and a holding inner `when` with a value
When packed
Then hex as at HEAD (b8b2809).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1..3 | 3 positions x bits/packed/sized | refused |
| AC-4 | 3 unchanged rows per position | hex unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| — | covered by unit tests | — | — | — |

## Constraints

- Probe first; record per package which positions are spellable (C++ typed rows may not spell "no value", see AZ-2432).
