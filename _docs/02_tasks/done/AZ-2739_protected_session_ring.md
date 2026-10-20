---
loop: 46
branch: dev
---

# Protected session payload in the session cross-language check (EC-D2)

**Task**: AZ-2739_protected_session_ring
**Name**: Protected session payload in the ring (EC-D2)
**Description**: One protected session payload is written by each of the eight languages and read by every language pair that reads the unprotected session payload.
**Complexity**: 5 points
**Dependencies**: None
**Component**: `.github/workflows/language-pair.sh`, `ring-wiring.test.sh`, the eight session drivers under `.github/workflows/drivers/`
**Tracker**: AZ-2739
**Epic**: AZ-2645

## Problem

The session cross-language check has no parity bytes. Each package tests its own protected session payload (the padded clear bytes plus the reference parity), so the eight agree by construction, but no test makes one language read another language's protected session payload (loop 45 assessment, row EC-D2). The owner (2026-10-20, answer B) asked for one payload in the check, both directions as for the unprotected one.

## Outcome

- A language that pads, orders or encrypts the protected bytes differently from the others fails the check.

## Scope

### Included
- A protected session payload: the position row of the unprotected `session` row, parity n = 4, the same session seed and nonce.
- A pack command and an unpack command for it in the driver of each of the eight languages, and in `language-pair.sh` one expected hex and the rows: eight pack checks and the same `handoff <from> <to>` pairs as the unprotected `session` rows.
- The expected value computed from the reference codec `scripts/ecc/eccfmt.py` (not copied from one language).
- `ring-wiring.test.sh` and any other script that reads the exact lines of `language-pair.sh`, updated to the new rows.

### Excluded
- Damaged protected session payloads in the ring (the plain ECC ring already covers repair; the session is proven per package).
- Concurrent use of one protected session from two threads.
- Any change under a package's source directory.

## Acceptance Criteria

**AC-1: Same bytes** (TW-6)
Given the session seed, the nonce, the position row and n = 4
When each of the eight languages packs the protected session payload
Then the eight payloads are equal to each other and to the value computed from the reference codec.

**AC-2: Cross-read** (TW-6)
Given the protected payload written by one language
When every language pair that reads the unprotected session payload reads the protected one
Then each read returns the position row, in both directions; mismatches are 0.

**AC-3: A missing command fails loudly**
Given a driver without the protected session command
When the check runs
Then it exits non-zero and names the language.

**AC-4: CI time**
Given the group of `language-pair.sh`
When the check runs with the new rows
Then the added time is at most 15 seconds; the figure is read from the CI annotations after the push.

## Non-Functional Requirements

**Performance**
- No new CI job and no new build; drivers are built once as today.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | 8 pack checks | equal hex |
| AC-2 | the session pairs | all read |
| AC-3 | `ring-wiring.test.sh` and the self-tests that read `language-pair.sh` | green with the new rows |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | `bash .github/workflows/language-pair.sh` with `PACKBIN_CXX_SYSROOT` and Python 3.10+ (`AGENT_GOTCHAS.md`) | the whole ring | "language pairs passed" | Performance |

## Constraints

- Before committing: `git grep` every reader of the lines of `language-pair.sh` and run each one (`AGENT_GOTCHAS.md`, loop 34 and 39). A worker never runs `git stash/checkout/reset/clean/add/rm/mv`.
- The runtime lock is held for the ring run.

## Risks & Mitigation

**Risk 1: A language differs**
- *Risk*: the ring finds a real difference in padding or order between two packages.
- *Mitigation*: stop and report it with both hex strings; no production fix without the owner (a real difference is a finding, not a test change).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ring is the slowest CI job group | one payload; about 5 s added locally; the CI figure is read after the push | open | Low |
| `language-pair.sh` is 545 lines (was 495), over the 500-line soft cap; the wiring tests match its exact lines, so a split is a task of its own | split by responsibility in a later loop | open | Medium |
