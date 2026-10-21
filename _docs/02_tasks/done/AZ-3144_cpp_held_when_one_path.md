---
loop: 56
branch: dev
---

# C++ one path for held whens

**Task**: AZ-3144_cpp_held_when_one_path
**Name**: C++ held-`when` single path
**Description**: The `When` and `FlagBit` handling of `unpack_children` and `unpack_one` is one function, within flash and stack budgets, or not made with the figures recorded.
**Complexity**: 3 points
**Dependencies**: AZ-3143
**Component**: `cpp/src/core/unpack.cpp`, `cpp/embedded/common/all_kinds.cpp` and `.hpp` (a `times`-round chain), `cpp/embedded/arm/`, `cpp/tests/core`
**Tracker**: AZ-3144
**Epic**: AZ-2645

## Problem

The held-`when` and flag-bit handling exists twice: in `unpack_children` and in the `When` / `FlagBit` cases of `unpack_one` (used by `unpack_table`, a `times` round and a flags member). A fix to one can miss the other (review #1, Medium). The stack of a chain reached through a `times` round was never measured.

## Outcome

- One function owns the handling; both callers use it.
- Flash at most 8120 B (no more than today); 3-deep chain stack at most 504 B and flag-byte chain at most 500 B.
- The chain through a `times` round is measured and recorded.

## Scope

### Included
- The fold; a third image scheme with a 3-deep `when` chain inside a `times` round, with rows checked against Python bytes on host, M3/s390x and M4F; the new figure in `AGENT_GOTCHAS.md` and the C++ description.

### Excluded
- Any wire change; a depth limit (owner decision); other packages.

## Acceptance Criteria

**AC-1: One function** — Given `unpack.cpp`, When read, Then the `When` and `FlagBit` handling appears in one function that `unpack_children` and `unpack_one` call. If the flash does not allow it, the fold is not made and the report gives the byte figures.

**AC-2: Budgets** — Given the Cortex-M4F image, When measured, Then flash at most 8120 B and stack of the two chains not above 504 B / 500 B.

**AC-3: Chain through a `times` round** — Given a 3-deep `when` chain inside a `times` round, When measured, Then the stack is at most 512 B, or a ticket with the figure is opened; packets equal Python's.

**AC-4: Packets unchanged** — Given the hostile and differential corpora, When run, Then host, `gcc:16` and arm stages pass with no new skip.

## Non-Functional Requirements

**Compatibility**: no wire change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2, AC-3 | arm embedded stage with the new image scheme | figures recorded, within bounds |
| AC-3, AC-4 | host comparison of image rows vs Python bytes; full C++ suites | 0 differences |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The fold may not fit the flash | measure after AZ-3143; if not, no fold | open | Medium |
| The fold may deepen the walk (margin 8 B) | measure before commit | open | Medium |

## Outcome of loop 56

AC-1 as allowed outcome: the fold was tried (one `unpack_held`) and not kept: flash 8,140 B and stack 676 B net. AC-2, AC-3 and AC-4 met on the unfolded code (flash 8,080 B, chain through a `times` round 436 B net, packets equal Python's).
