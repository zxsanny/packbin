---
loop: 82
branch: dev
---

# ring-wiring and ring-wiring-swift checks in Python

**Task**: AZ-3384_ring_wiring_python
**Name**: ring-wiring and ring-wiring-swift checks in Python
**Description**: The ring job wiring checks against `test.yml` and the compose file run in Python for both the main ring and the Swift ring.
**Complexity**: 5 points
**Dependencies**: AZ-3381
**Component**: CI scripts (`.github/workflows/`, `test.yml`, `tool-pins.txt`)
**Tracker**: AZ-3384
**Epic**: none

## Problem

`ring-wiring.test.sh` (278 lines) embeds 117 lines of Ruby (lines 18-136) and `ring-wiring-swift.test.sh` (425 lines) embeds 68 lines (lines 44-113); both refuse at `command -v ruby`.

## Outcome

- Both scripts run on the shared reader with every check and mutant kept.

## Scope

### Included

- The two embedded programs ported; the two `ruby is required` guards become the PyYAML guard.
- Both files at or under 500 lines.

### Excluded

- `ring-wiring-rows.test.sh`, `ring-wiring-lib.sh` (no Ruby) unchanged unless the port needs a shared call.
- The ring itself.

## Acceptance Criteria

**AC-1: Same wiring checks**
Given `test.yml` and `docker-compose.test.yml` at HEAD
When each ported script runs
Then exit 0; every labelled check of HEAD runs (0 dropped)

**AC-2: Each rule fails on a mutation**
Given the mutants each script holds at HEAD
When each ported script runs on each
Then each exits non-zero naming the check (0 lost)

**AC-3: No Ruby**
Given a host with no `ruby`
When both scripts run
Then both exit 0; neither prints `ruby is required`

## Non-Functional Requirements

**Compatibility**
- Runs with `python3 -I` on the Python of this host (3.14.4) and of the CI jobs; uses only features both have.

**Reliability**
- A reader failure is a failure of the script that called it; no script goes on with an empty value.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | labels counted from source before and after | equal or more |
| AC-2 | mutants | all rejected |
| AC-3 | no ruby | exit 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | this host | `bash ring-wiring.test.sh` and `bash ring-wiring-swift.test.sh` | both pass | - |

## Constraints

- No stand-in: every check of the replaced script is kept (label list taken from the source at HEAD 5a78fb8 before the change); a check that cannot be kept goes to the owner, never dropped.
- Each ported script is proven by one deliberate mutation of what it guards (it exits non-zero and names the check) and runs green on a host without `ruby`.
- Each file stays at or under 500 lines; split by responsibility.
- Inherits project AC-11, AC-12, AC-14, AC-15 unchanged in meaning.

## Risks & Mitigation

**Risk 1: a wiring edge is read differently**
- *Risk*: Ruby `dig`/`Hash` behaviour on missing keys differs from Python `dict`.
- *Mitigation*: a mutant that removes each edge; explicit missing-key handling.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Missing-key semantics differ between Ruby and Python | a mutant per removed edge | open | Medium |
