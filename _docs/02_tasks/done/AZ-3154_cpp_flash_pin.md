---
loop: 57
branch: dev
---

# C++ arm stage flash pin

**Task**: AZ-3154_cpp_flash_pin
**Name**: Cortex-M4F flash pin
**Description**: The arm embedded stage fails above the recorded flash figure, not only above 8,192 B.
**Complexity**: 1 point
**Dependencies**: AZ-3152
**Component**: `cpp/embedded/arm.sh`, `cpp/embedded/lib.sh`
**Tracker**: AZ-3154
**Epic**: AZ-2645

## Problem

Nothing asserts the recorded flash figure; a later edit can spend the whole margin with no stage saying so.

## Outcome

- A pinned figure (the one measured after AZ-3151 and AZ-3152) that the stage enforces, and the margins written to the docs.

## Scope

### Included
- A pin in `lib.sh` read by `arm.sh`; failure message naming measured and pinned bytes; margins in `_docs/AGENT_GOTCHAS.md` and the C++ description (the parent writes them from the report).

### Excluded
- Stack pins; other targets.

## Acceptance Criteria

**AC-10: Pin** — Given the arm stage, When the Cortex-M4F flash is above the pin, Then the stage fails naming measured and pinned bytes; a raise needs an edit of the pin and a line in `AGENT_GOTCHAS.md`. Shown on a copy with the pin one byte below the measured figure.

**AC-11: Margins recorded** — Given the final figures, When the loop closes, Then `AGENT_GOTCHAS.md` and the C++ description state the flash and stack margins.

## Non-Functional Requirements

**Compatibility**: no wire change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-10 | arm stage on a copy with pin = measured - 1 | fails with both figures |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The pin value depends on AZ-3151/AZ-3152 outcomes | set last | open | Low |

## Outcome of loop 57

AC-10 met: `flash_pin=8032` in `cpp/embedded/lib.sh`, checked in `arm.sh` `target_m4f`; with the pin at 8,031 B on a copy the stage fails with `flash 8032 B measured is over the pin of 8031 B`. AC-11 is written by the parent in step 13.
