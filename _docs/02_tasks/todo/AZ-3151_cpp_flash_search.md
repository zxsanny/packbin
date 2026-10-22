---
loop: 57
branch: dev
---

# C++ flash search

**Task**: AZ-3151_cpp_flash_search
**Name**: C++ core flash search (image at most 8,040 B)
**Description**: At least 40 B of flash is saved in the C++ core without changing any packet or refusal.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/src/core/`, `cpp/include/packbin/`, `cpp/embedded/` (measurement), `cpp/tests/core`
**Tracker**: AZ-3151
**Epic**: AZ-2645

## Problem

AZ-3143 saved 40 B and missed its 8,040 B target: the Cortex-M4F image is 8,080 B (margin 112 B). Any later edit of `cpp/src/core` or `cpp/include` needs a saving first, and the fold of AZ-3152 needs about 60 B.

## Outcome

- Flash image at most 8,040 B (margin at least 152 B).
- Packets, refusals and stack figures unchanged.

## Scope

### Included
- Find savings by size per symbol (`arm-none-eabi-nm --size-sort`, per-object `size`) in `cpp/src/core` and `cpp/include/packbin`; apply those that keep behavior identical; measure with the arm embedded stage once per candidate set.

### Excluded
- Any wire change, removed check or changed refusal; a depth limit; other packages; the fold (AZ-3152).

## Acceptance Criteria

**AC-1: Flash** — Given the Cortex-M4F flash image, When built after the change, Then at most 8,040 B. A smaller saving is reported with the figure and AC-1 recorded as not met, never loosened.

**AC-2: No behavior change** — Given the shared hostile and differential corpora, When run, Then every packet and refusal is byte-identical to HEAD; `make -C cpp test` (host), `gcc:16 make test` and the arm embedded stage pass with no new skip; stack not above 504 B (deepest), 500 B / 384 B (flag chain unpack / pack), 292 B / 348 B (plain chain), 436 B (round chain); `cpp-avr-uno` and `PACKBIN_NO_TEXT` stay inside their margins; `static_assert(offsetof(Field, eq) == 16)` holds.

## Non-Functional Requirements

**Compatibility**: no wire change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | arm embedded stage flash figure | at most 8,040 B |
| AC-2 | full C++ suites listed above; shared corpora | pass, 0 differences |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Saving may be below 40 B | report the figure; ticket, no loosened bound | open | Medium |
| A saving by dropping a check changes behavior | corpora must be identical to HEAD | open | High |
| Stack margin 8 B | measure before commit | open | Medium |
