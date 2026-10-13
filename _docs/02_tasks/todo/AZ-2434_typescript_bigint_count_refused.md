---
loop: 23
branch: dev
---

# TypeScript refuses a bigint count above 2^53 behind a clear when

**Task**: AZ-2434_typescript_bigint_count_refused
**Name**: TypeScript refuses a bigint count above 2^53 behind a clear when (U23)
**Description**: In the U11 shape TypeScript treats a bigint count above 2^53 as "not a count" and packs; the four refuse.
**Complexity**: 1 point
**Dependencies**: none
**Component**: typescript
**Tracker**: AZ-2434
**Epic**: AZ-2069

## Problem

Owner decision U23 A (2026-10-13); review22 finding 8. `refuseUnwrittenCount` (`typescript/src/flag-bits.ts`) uses `validCount`, which returns null for a bigint above 2^53, so `{mode: 0, c: 2n**60n}` with a `bits`/`packed`/`sized` member behind a clear `when` packs `010000`. Python (`2**60`), Rust (`U64(1<<60)`), Java (`positive`) and C# (`IsPositive`) refuse with the U11 message.

## Outcome

- A bigint count above 2^53 (above 0) in the U11 shape is refused with the U11 `RangeError` message, naming the member and the count.
- Floats, strings, NaN, booleans, negative counts, null, `0n` and safe bigints behave as at HEAD.

## Scope

### Included
- `typescript/src/flag-bits.ts` (and `kinds.ts` only if the check belongs there) and TypeScript tests.

### Excluded
- The same split for `times` (U6, documented); other packages.

## Acceptance Criteria

**AC-1: large bigint refused**
Given the U11 shape for `bits`, `packed` and `sized` and counts `2n**60n` and `2n**53n + 1n`
When packed
Then `RangeError` with the U11 text naming the member and the count.

**AC-2: unchanged rows**
Given counts `0n`, `3n`, `3`, `3.5`, `-1`, `"3"`, `NaN`, `true`, `null`, left out
When packed
Then hex as at HEAD (b8b2809).

**AC-3: parity**
Given the same rows in Python
When compared
Then the refused/packed outcome matches for every row of AC-1 and AC-2 (recorded in the test or batch report).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | 3 kinds x 2 large counts | RangeError |
| AC-2 | non-count values | hex unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | hostile loader (typescript), 65 cases | `npm test` | all pass | — |

## Constraints

- Strict check: `typescript/node_modules/.bin/tsc --noEmit --strict ...` per AGENT_GOTCHAS.
