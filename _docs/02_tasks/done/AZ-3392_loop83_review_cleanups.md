---
loop: 84
branch: dev
---

# Loop 83 review cleanups

**Task**: AZ-3392_loop83_review_cleanups
**Name**: Handoff include lists and the id-padded needle
**Description**: Prune includes that a part does not use; make the `id-padded` test independent of the 5-line cap.
**Complexity**: 2 points
**Dependencies**: None (AZ-3387 and AZ-3389 are shipped)
**Component**: Ring drivers and tests (`.github/workflows/drivers/handoff_ecc.cpp`, `handoff_frame.cpp`, `ring-frame.test.sh`, `scripts/frame/ring_frame.py`)
**Tracker**: AZ-3392
**Epic**: none

## Problem

Two review findings of loop 83 are real on HEAD:
1. `handoff_ecc.cpp` includes 5 headers (`cstdio fstream sstream string vector`) and `handoff_frame.cpp` 8 (`cctype cstdio cstring fstream sstream stdexcept string vector`), copied from the 639-line original; a part may use fewer.
2. `ring-frame.test.sh:184` expects "go: R.open.id7 open gave TagMismatch" from the mismatch list, which `ring_frame.py:38` (`SHOWN = 5`) caps at 5 lines per reader; a new row sorted ahead of the needle breaks the test.

Two are **not defects on HEAD** (probed): `kMax` is read by `handoff.cpp` (178, 252, 263, 277) and `handoff_ecc.cpp` (52, 67), not by one part; `frame_hex` wraps `hex_of` on purpose (`-` is the wire word for an empty field, `hex_of` prints nothing). They stay.

## Outcome

- Each include of the two parts is used there, or removed.
- The `id-padded` test does not depend on how many rows sort before its needle.

## Scope

### Included
- For each header in the two parts: grep the symbols it provides; remove it only with 0 uses in that file; record the count removed.
- The `id-padded` test: lift or work around the cap in the test (e.g. an environment/argument for `SHOWN`, or a needle taken from the head of the sorted list), whichever changes least; `ring_frame.py` default output unchanged.
- Record the C++ driver's output over the 108 invocations of loop 83 (`smoke83.sh`/`record83.md` give the set) before and after.

### Excluded
- `kMax`, `frame_hex`, `hex_of` (see Problem); `handoff.cpp` includes unless the same 0-use rule shows one (then say so, one line).
- Any change of ring rows or driver behaviour.

## Acceptance Criteria

**AC-1: Includes used**
Given the two parts after the task
When each header's symbols are grepped in the part
Then every remaining include has 1 or more uses; the count removed is recorded

**AC-2: Build and output**
Given the one compile line of `ring-lib.sh` with `-std=c++17 -O2 -Wall -Wextra -Werror` (gcc:16)
When the driver builds and runs the 108 invocations
Then 0 warnings and stdout, stderr and exit code are byte-identical to the HEAD binary

**AC-3: Needle independent of the cap**
Given a scratch copy of `ring-cases.txt` with 10 extra rows that sort ahead of the needle
When `ring-frame.test.sh` runs
Then `id-padded` passes, and it still fails when the go driver pads the id (`FAKE_LIE=go:id-padded` caught)

**AC-4: Default output unchanged**
Given `bash .github/workflows/ring-frame.sh`
When it runs after the task
Then the pair counts and `0 mismatched` are those of HEAD; `ring-frame.test.sh` and `ring-frame-drivers.test.sh` pass

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | symbol grep per header | each remaining header used |
| AC-3 | `id-padded` with 10 extra rows (scratch) | passes; lying go driver still caught |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | 108 invocations | HEAD vs new C++ driver | identical | none |
| AC-4 | real rows | `ring-frame.sh` | as HEAD | none |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A pruned header was reached only through another | AC-2 builds with `-Werror` on gcc:16 | open | Medium |
