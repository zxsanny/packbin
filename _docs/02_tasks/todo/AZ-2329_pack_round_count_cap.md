---
loop: 19
branch: dev
---

# `pack` of a `times` whose count is large but whose value is a lone scalar (or missing) refuses a count above the scheme's `maxRounds` (default 65 535) with an error naming the member, instead of looping n rounds

**Task**: AZ-2329_pack_round_count_cap
**Name**: Pack round count cap
**Description**: `pack` of a `times` whose count is large but whose value is a lone scalar (or missing) refuses a count above the scheme's `maxRounds` (default 65 535) with an error naming the member, instead of looping n rounds.
**Complexity**: 3 points
**Dependencies**: AZ-2216 to AZ-2220 (done)
**Component**: typescript, python, java, csharp, rust (C++ is not affected: fixed arrays, capacity 65 535)
**Tracker**: AZ-2329
**Epic**: AZ-2069

## Problem

Owner decision 1 (review R1, security F21) of loop 19 (2026-10-11, option A, accepted as recommended). Pack of a `times` with a lone scalar or no value loops `n` rounds for any `n` in TypeScript, Python, Java, C# and Rust: a 4-billion count costs 4 GiB or about 80 minutes. Unpack already refuses a round above `maxRounds` (loop 15, AZ-2216 to AZ-2220); pack does not.

## Outcome

- Pack refuses a `times` count above `maxRounds` before it writes any round, naming the member.
- A count at or below the limit packs exactly as before.

## Scope

### Included
- Check the count against the scheme `maxRounds` in `pack` in the five packages (probe each first and write the per-package table in the batch report).
- Hostile case `pack_times_count_over_limit` in the wave 2 fixture work (the `pack` stage).

### Excluded
- Changing the unpack limit or its default; C++ (capacity-bound already).

## Acceptance Criteria

**AC-1: pack refuses an over-limit count**
Given a `times` scheme and a count of `maxRounds + 1` with a lone scalar
When packed in each of the five packages
Then an error naming the member is returned and no bytes are produced; peak memory stays flat

**AC-2: count at the limit still packs**
Given a count of `maxRounds` with one scalar
When packed and unpacked
Then bytes equal to today's and the row round-trips

**AC-3: a scheme that raised maxRounds packs a larger count**
Given `maxRounds` raised to 70 000 and a count of 70 000
When packed
Then packed without error

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | count `maxRounds + 1` | error naming member, in 5 packages |
| AC-2 | count `maxRounds` | bytes unchanged |
| AC-3 | raised limit | packs |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_times_count_over_limit` replayed by five packages | error, no bytes | — |

## Constraints

- ADR-001: each package implements it itself. The cap uses the scheme's existing `maxRounds`, no new limit property.
- Wire bytes of every accepted row are unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Reusing `maxRounds` (a decoder limit) as an encoder limit means a scheme that lowers it also lowers what it can pack | coordinator | open | Low |
