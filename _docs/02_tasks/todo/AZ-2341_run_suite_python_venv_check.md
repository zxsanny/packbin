---
loop: 19
branch: dev
---

# `run-suite

**Task**: AZ-2341_run_suite_python_venv_check
**Name**: run-suite python venv check
**Description**: `run-suite.sh python` checks the venv is usable (not only `bin/pytest` exists) and otherwise rebuilds it or fails with a message naming the broken path.
**Complexity**: 1 points
**Dependencies**: None
**Component**: harness (`run-suite.sh`)
**Tracker**: AZ-2341
**Epic**: AZ-2069

## Problem

Owner decision clear gap (G2) of loop 19 (2026-10-11, option A, accepted as recommended). The check passes on a venv whose interpreter is broken, and the failure appears later as an unrelated error.

## Outcome

- A broken venv gives a clear message or is rebuilt.

## Scope

### Included
- The check and a harness test.

### Excluded
- Other packages' venvs.

## Acceptance Criteria

**AC-1: broken venv detected**
Given a venv with a missing interpreter
When `run-suite.sh python`
Then exit non-zero with a message naming the venv path, or a rebuilt venv that passes

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | broken venv | message |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | harness self-test | script test | passes | — |

## Constraints

- Shell hygiene of AGENT_GOTCHAS.md.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | coordinator | resolved | Low |
