---
loop: 28
branch: dev
---

# Publish gate test: timing line per check group

**Task**: AZ-2563_ci_gate_timings
**Name**: Publish gate timings
**Description**: Each check group of the publish gate test reports the seconds it took, so the next loop can cut the gate by evidence.
**Complexity**: 2 points
**Dependencies**: None
**Component**: ci
**Tracker**: AZ-2563
**Epic**: AZ-2223

## Problem

The publish gate test takes 1 077 s on the Mac (1 060 to 1 245 s in CI) and prints no time per check group; the Swift scenarios are 330 s, about 750 s is unattributed.

## Outcome

- One line `publish-gate: <check> took N s` for each of the 14 check groups, and a total line.
- Zero assertions removed or changed.

## Scope

### Included
- The run order in `.github/workflows/publish-gate.test.sh` (and a sibling file if the 500-line cap needs it); a test that the 14 lines print, also when a group fails.

### Excluded
- Cutting any group (next loop); the CI job split (AZ-2564).

Feature ACs: `_docs/02_task_plans/ci-split-and-leftovers/acceptance_criteria.md`. Scenarios: `scenarios.md` in the same folder.

## Acceptance Criteria

**AC-1: One timing line per group (SP-5, S-6)**
Given the publish gate test
When it runs to the end
Then 14 lines `publish-gate: <check> took N s` print (static, crates-token, registry, vcpkg, gate, go, swift, manifest, npm, position, workflow, pins, phases, readonly) and a total line, and the last line is unchanged (`publish gate tests passed` or the NOT RUN form)

**AC-2: A failing group is still timed (S-7)**
Given one group fails
When the test runs
Then its timing line prints, the failure count is the same as without the timing code, and the exit code is 1

**AC-3: No assertion changed (SP-5)**
Given the existing mutant and negative proofs of every group
When the test runs before and after
Then the counts of failures, mutants rejected and NOT RUN names are equal

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | run the gate test (or a stub run through the timing wrapper) | 14 timing lines + total |
| AC-2 | a group stubbed to fail | timing line present, exit 1 |
| AC-3 | diff of the assertion output before and after | equal counts |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | Mac with Docker | `bash .github/workflows/publish-gate.test.sh` | 14 lines + passes | SP-5 |

## Constraints

- Source files stay at or under 500 lines (`publish-gate.test.sh` is 492).
- Shell rules: `set -euo pipefail`, bash 3.2 safe, no silent `2>/dev/null`.

## Risks & Mitigation

**Risk 1: Timing code changes a group's exit handling**
- *Risk*: a wrapper swallows a failure.
- *Mitigation*: AC-2 runs a failing group; the failure count must be equal.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Smoke scripts grep the gate's last line | keep it unchanged | open | Low |
