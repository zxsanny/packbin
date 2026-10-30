---
loop: 84
branch: dev
---

# Scaffold wiring check requires the two CI helper-test steps

**Task**: AZ-3390_scaffold_requires_helper_test_steps
**Name**: Scaffold wiring check requires the yaml_get and workflow_yaml test steps
**Description**: `SCAFFOLD_SCRIPTS` names the two steps; a mutant per step proves deleting one is caught.
**Complexity**: 3 points
**Dependencies**: None (AZ-3388 is shipped)
**Component**: CI scripts (`.github/workflows/ring-wiring-check.py`, `ring-wiring.test.sh`)
**Tracker**: AZ-3390
**Epic**: none

## Problem

`SCAFFOLD_SCRIPTS` (`ring-wiring-check.py:27`) lists 3 scripts the `scaffold` job must run. The steps "CI YAML reader" (`bash scripts/ci/yaml_get.test.sh`) and "CI workflow helpers" (`bash scripts/ci/workflow_yaml.test.sh`) of `test.yml` are not in it: deleting either leaves every wiring test green (loop 83 review finding 1; L83-2). `ring-wiring.test.sh:122-124` holds one mutant per listed step.

## Outcome

- The check requires both steps, with the same rules as the 3 existing ones (present in `scaffold`, no `if`, no `continue-on-error`).
- Each new entry has a mutant that deletes its step and is rejected for that step.

## Scope

### Included
- Two entries in `SCAFFOLD_SCRIPTS` with a "what" text each.
- Two mutants in `ring-wiring.test.sh` built like the existing three (`no-wiring-step` etc.), listed after them.
- Record the mutant and label counts of the three wiring tests on HEAD before editing (the baseline for AC-2).

### Excluded
- Any other check, message or entry; `ring-wiring-swift-check.py` (it has no scaffold list).
- The Python-version change (AZ-3393): the same worker does it after this task, in a separate step.
- `test.yml` content (the steps exist).

## Acceptance Criteria

**AC-1: Five entries**
Given `ring-wiring-check.py` after the task
When `SCAFFOLD_SCRIPTS` is read
Then it has 5 entries (HEAD: 3) and the two new ones are `scripts/ci/yaml_get.test.sh` and `scripts/ci/workflow_yaml.test.sh`

**AC-2: Real file clean, mutants counted**
Given the real `test.yml` and compose file
When the checker runs, and the three wiring tests run
Then 0 violations (exit 0); `ring-wiring.test.sh` passes with 2 more mutants than HEAD; `ring-wiring-rows.test.sh` and `ring-wiring-swift.test.sh` output identical to HEAD

**AC-3: Deleting a step is caught**
Given copies of `test.yml` with the "CI YAML reader" step removed, and with the "CI workflow helpers" step removed
When the checker runs on each
Then exit 1 and a message naming `scripts/ci/yaml_get.test.sh` / `scripts/ci/workflow_yaml.test.sh` (HEAD: exit 0 for both)

**AC-4: Guards like the others**
Given a copy where either step has `if: always()` or `continue-on-error: true`
When the checker runs
Then exit 1 (same message shape as for `lib.test.sh`)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | count of `SCAFFOLD_SCRIPTS` entries | 5 |
| AC-3 | 2 new mutants in `ring-wiring.test.sh` | both rejected for their script |
| AC-4 | one `if`/`continue-on-error` mutant per new script (scratch) | exit 1 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | real `test.yml` | the three wiring tests | pass; counts as stated | none |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A mis-spelled entry matches no step and rejects the real file, or worse, nothing | AC-2 (real file clean) and AC-3 (message names the script) | open | High |
