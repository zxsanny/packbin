---
loop: 85
branch: dev
---

# Ring wiring check rejects a job-level RING_PYTHON

**Task**: AZ-3412_ring_wiring_job_level_python
**Name**: Ring wiring check rejects a job-level RING_PYTHON
**Description**: A job that sets its own `RING_PYTHON` in its env is rejected by `ring-wiring-check.py`; the version lives at workflow level.
**Complexity**: 1 point
**Dependencies**: none
**Component**: CI (`.github/workflows/ring-wiring-check.py`, `ring-wiring.test.sh`)
**Tracker**: AZ-3412
**Epic**: none

## Problem

`ring-wiring-check.py` merges workflow and job env only for the ring job (`suite_errors`, line 92); `python_errors` checks the `setup-python` expression of every job. A `test.yml` copy with `env: RING_PYTHON: "3.12"` in `scaffold` gives exit 0 on HEAD a9c2694 (probe 2026-10-30), though the version lives at workflow level since AZ-3393 and the compose image is `python:3.14`.

## Outcome

- A job-level `RING_PYTHON` in any job is rejected with a message naming the job.
- The real files stay at 0 violations; the legitimate job-level `RING_*` versions of the `ring` job are untouched.

## Scope

### Included
- A check in `ring-wiring-check.py` for a job-level `RING_PYTHON` (a job `env` key), message names the job and the variable.
- One mutant in `ring-wiring.test.sh`.

### Excluded
- Other `RING_*` variables in non-ring jobs (none exists; not probed as a risk).
- Any change to `test.yml`.

## Acceptance Criteria

**AC-1: Override rejected**
Given a copy of `test.yml` with `RING_PYTHON: "3.12"` in the job env of `scaffold`
When `ring-wiring-check.py` runs on it with the real compose file
Then exit 1 and one line naming `scaffold` and `RING_PYTHON` (HEAD: exit 0)

**AC-2: Real files unchanged**
Given the real `test.yml` and `docker-compose.test.yml`
When the checker runs, and `ring-wiring.test.sh` runs
Then exit 0, 0 violations; the 42 existing mutants keep their verdicts

**AC-3: Mutant added**
Given `ring-wiring.test.sh`
When it runs
Then it holds 43 mutants including the one of AC-1 and passes

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-3 | mutant "RING_PYTHON set in a job env" | rejected |
| AC-2 | the 42 existing mutants and the real pair | as HEAD |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | real files | `ring-wiring.test.sh`, `ring-wiring-rows.test.sh` | PASS | none |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rejecting a job-level `RING_PYTHON` must not reject the `ring` job's own `RING_*` versions | AC-2 | open | Low |
