---
loop: 84
branch: dev
---

# One place for the Python version in test.yml

**Task**: AZ-3393_python_version_one_place
**Name**: One place for the Python version
**Description**: `RING_PYTHON` lives at workflow level; the `setup-python` literals read it; the wiring check still compares it with the compose image.
**Complexity**: 3 points
**Dependencies**: AZ-3390 (same two files: `ring-wiring-check.py`, `ring-wiring.test.sh`; the same worker does AZ-3390 first)
**Component**: CI (`.github/workflows/test.yml`, `ring-wiring-check.py`, `ring-wiring.test.sh`)
**Tracker**: AZ-3393
**Epic**: none

## Problem

`test.yml` spells Python 3.14 three times: `RING_PYTHON: "3.14"` (job env of `ring`, line 23) and `python-version: "3.14"` in jobs `publish-gate-rest` (251) and `scaffold` (336). The suite image `python:3.14` (`docker-compose.test.yml:33`) is compared with `RING_PYTHON` by `SUITES` (`ring-wiring-check.py:25`), which reads the job env. A bump needs 4 edits and a missed literal is not caught. `publish.yml` has no `setup-python` step.

## Outcome

- One value in `test.yml`, at workflow level; the three `setup-python` steps read `${{ env.RING_PYTHON }}`.
- A literal `python-version` in any job is rejected; a `RING_PYTHON` that differs from the compose image still is.

## Scope

### Included
- Move `RING_PYTHON` to a workflow-level `env:`; replace the two literals.
- `ring-wiring-check.py` reads `RING_PYTHON` (and any other `RING_*` it compares) from workflow env as well as job env, with the same message when it differs from the image tag.
- A check that every `python-version:` in `test.yml` is the `RING_PYTHON` expression; one mutant in `ring-wiring.test.sh` with a literal, and one with `RING_PYTHON: "3.13"` if no existing mutant covers it (the worker names which).
- `ring-toolchains.sh` keeps reading `RING_PYTHON` from the environment (the `ring` job must still export it: check it does after the move).

### Excluded
- The other `RING_*` versions; the `python:3.14` in `publish-phases.test.sh` and `scripts/loop-tests.sh` (host recipes, not CI wiring).
- The scaffold list (AZ-3390).

## Acceptance Criteria

**AC-1: One value**
Given `test.yml` after the task
When `grep -c '3\.14' .github/workflows/test.yml` runs
Then 1 (HEAD: 3) and no `python-version:` line holds a literal

**AC-2: Compose comparison kept**
Given the real files, and a copy with `RING_PYTHON: "3.13"`
When the checker runs on each
Then exit 0 on the real pair (0 violations); exit 1 on the copy with a message that the version differs from the compose image

**AC-3: Literal rejected**
Given a copy of `test.yml` with `python-version: "3.14"` in `scaffold`
When the checker runs
Then exit 1 (HEAD: exit 0)

**AC-4: Pins guard**
Given `publish-pins.test.sh`
When it runs
Then it passes: every job that reads the CI YAML still has `setup-python` and the pinned PyYAML install

**AC-5: ring job still checks toolchains**
Given the `ring` job
When `ring-toolchains.sh` reads `RING_PYTHON`
Then the variable is set in that job (workflow env is inherited); the checker's other `RING_*` comparisons give the same result as HEAD

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `grep -c` | 1 |
| AC-2, AC-3 | mutants in `ring-wiring.test.sh` | rejected |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | real files | `publish-pins.test.sh` | PASS | none |
| AC-5 | real `test.yml` | wiring tests; read `ring` job env | as HEAD | none |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The checker reads job env only today; workflow env must be merged, or the version comparison silently stops | AC-2 (the 3.13 copy is rejected) | open | Medium |
