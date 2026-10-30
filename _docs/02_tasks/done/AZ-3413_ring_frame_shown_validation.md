---
loop: 85
branch: dev
---

# ring_frame.py rejects a bad RING_FRAME_SHOWN with one line

**Task**: AZ-3413_ring_frame_shown_validation
**Name**: ring_frame.py rejects a bad RING_FRAME_SHOWN with one line
**Description**: A `RING_FRAME_SHOWN` that is not an integer from 1 to 1000000 gives one message and exit 2, not a traceback.
**Complexity**: 1 point
**Dependencies**: none
**Component**: scripts (`scripts/frame/ring_frame.py`, `.github/workflows/ring-frame.test.sh`)
**Tracker**: AZ-3413
**Epic**: none

## Problem

`ring_frame.py:38` reads `int(os.environ.get("RING_FRAME_SHOWN", "5"))` at import. `RING_FRAME_SHOWN=abc` ends in `ValueError: invalid literal for int()` (probe 2026-10-30). The variable is hand-set only; `0` or a negative number would silently show no mismatch line.

## Outcome

- A bad value gives one line naming the variable and the range, exit 2, no traceback.
- Good values and the default behave as on HEAD.

## Scope

### Included
- Validation of `RING_FRAME_SHOWN` in `ring_frame.py` with the existing exit-2 convention of `main` (usage/config error).
- One case in `ring-frame.test.sh`.

### Excluded
- Other environment variables of the ring scripts.

## Acceptance Criteria

**AC-4: Bad value**
Given `RING_FRAME_SHOWN` is `abc`, empty, `0`, `-1`, `1.5` or `1000001`
When `ring_frame.py check` runs
Then exit 2, exactly one line naming `RING_FRAME_SHOWN` and `1 to 1000000`, no `Traceback` (HEAD: `abc` gives a traceback, exit 1)

**AC-5: Good value and default**
Given `RING_FRAME_SHOWN` unset, and set to `1000`
When the ring runs
Then 5 and 1000 lines are shown at most; default `ring-frame.sh` output is identical to HEAD (64 pairs, 0 mismatched); the `id-padded` case stays green

**AC-6: Case added**
Given `ring-frame.test.sh`
When it runs
Then 1 new case sets a bad value, expects the message and no traceback (the harness `run` already fails on `Traceback`), and passes

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | six bad values, direct call | exit 2, one line |
| AC-5 | unset, `1000` | as HEAD |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5, AC-6 | fake drivers of `ring-frame.test.sh` | the suite | PASS | none |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Through `ring-frame.sh` the exit code may not be 2; the worker names what the wrapper returns and the case asserts that | AC-6 | open | Low |
