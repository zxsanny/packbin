---
loop: 20
branch: dev
---

# `pack` of a `repeat` whose list has more entries than `maxRounds` is refused naming the member

**Task**: AZ-2355_repeat_round_cap_on_pack
**Name**: Repeat round cap on pack
**Description**: A `repeat` list longer than the scheme's `maxRounds` is refused on pack, naming the member, before any round is written, so pack never writes a packet its own unpack refuses.
**Complexity**: 2 points
**Dependencies**: AZ-2329 (done); same worker as AZ-2354
**Component**: typescript (reference, first), python, java, csharp, rust
**Tracker**: AZ-2355
**Epic**: AZ-2069

## Problem

Owner decision 2 of loop 20 (assessment U1, security F31, option A). AZ-2329 caps a `times` count on pack; a `repeat` takes its rounds from the list length and is capped by nothing: `repeat { u8 k }` with 70 000 entries packs 70 001 bytes that the same scheme's unpack refuses (round 65 536).

## Outcome

- Pack refuses a `repeat` with more than `maxRounds` entries with the same typed error and wording shape as the `times` cap, naming the member.
- `maxRounds` entries pack as today.

## Scope

### Included
- The check in the five packages wherever a `repeat` is packed (top level, `flags` member, group, `when`, split bit, list/dict element). TypeScript's text goes into the AZ-2354 reference table.

### Excluded
- C++ (fixed arrays); unpack.

## Acceptance Criteria

**AC-1: over-limit repeat refused**
Given `repeat { u8 k }` with `maxRounds + 1` entries
When packed in each of the five packages
Then an error naming `k` and no bytes

**AC-2: at the limit packs**
Given `maxRounds` entries
When packed and unpacked
Then `maxRounds + 1` bytes and the row round-trips

**AC-3: raised limit**
Given `maxRounds` raised to 70 000 and 70 000 entries
When packed
Then packed without error

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | 65 536 entries | error naming member |
| AC-2 | 65 535 entries | packs, round-trips |
| AC-3 | raised limit | packs |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_repeat_over_limit` (AZ-2367) | error | — |

## Constraints

- **Reference:** rows 1 to 10 of the AZ-2355 table in `_docs/03_implementation/reference_loop20_budget.md`. The error names the first member whose list passes the limit (not the round's first member), text `{member}: the repeat count is {n}, above the limit of {maxRounds} rounds`.
- Wire bytes of accepted rows unchanged.
