---
loop: 28
branch: dev
---

# CI: split the scaffold job

**Task**: AZ-2564_ci_job_split
**Name**: CI job split
**Description**: `test.yml` runs the static checks, the 8 suites and the publish gate as parallel jobs, with every guard following the new layout.
**Complexity**: 5 points
**Dependencies**: AZ-2563_ci_gate_timings
**Component**: ci
**Tracker**: AZ-2564
**Epic**: AZ-2223

## Problem

One `scaffold` job runs the 8 suites (860 to 984 s) and then the gate (1 060 to 1 245 s): 1 977 to 2 295 s, 33 to 38 minutes end to end, with `ring` and `embedded` finished long before.

## Outcome

- Jobs `scaffold` (static checks), `suites` (8 languages one after the other) and `publish-gate` run in parallel beside `embedded` and `ring`; end to end at most 25 minutes.
- No check removed; guards follow the layout.

## Scope

### Included
- `.github/workflows/test.yml`; the guards that read the `scaffold` job: `publish-gate.test.sh` (job list, timeouts), `ring-wiring.test.sh` (steps of `scaffold`), `run-suite-swift.test.sh` (the `for lang in` list), `report-row.test.sh`; `publish-readonly.test.sh` comment on pulled images; a pull of the images the gate needs inside its own job; the `_docs/04_deploy/ci_cd_pipeline.md` timings.

### Excluded
- A job per language (Option B of Card 1); cutting the gate; the Mac gate in parallel.

Feature ACs: `_docs/02_task_plans/ci-split-and-leftovers/acceptance_criteria.md`. Scenarios: `scenarios.md` in the same folder.

## Acceptance Criteria

**AC-1: Five jobs green, publish still gated (SP-1, S-1, S-3)**
Given the pushed `dev` commit
When `test.yml` runs
Then jobs `scaffold`, `suites`, `publish-gate`, `embedded` and `ring` conclude `success` (5 of 5), and `publish.yml` still calls `test.yml` with `needs: test` unchanged; a red `suites` or `publish-gate` makes the call fail

**AC-2: Wall time and limits (SP-2, S-4, S-5)**
Given 2 consecutive CI runs on `dev`
When the end-to-end time is read
Then both are at most 25 minutes, each job is inside its `timeout-minutes`, the `publish gate` step is at most 1 500 s, and the gate job pulls every image it needs without relying on another job

**AC-3: Nothing removed (SP-3)**
Given the old and the new `test.yml`
When the `run:` commands are compared
Then every old command runs in exactly one new job (equal count) and the 8 `docker compose -f docker-compose.test.yml run --rm <lang>` suites are all present

**AC-4: Guards follow and still bite (SP-4, S-2)**
Given the four guards
When each runs against the real new `test.yml` and against mutants (a suite dropped, a step moved to a job with `if:` or `continue-on-error`, the gate step dropped, a job without `timeout-minutes`)
Then the real file passes and 100 % of the mutants are refused, one mutant per rule

**AC-5: One commit reverts it (S-12)**
Given the split commit
When it is reverted
Then `test.yml` and its guards return to the single-job form and the guards pass

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | script comparing run commands of old and new file | equal counts, 8 suites |
| AC-4 | `ring-wiring.test.sh`, `publish-gate.test.sh`, `run-suite-swift.test.sh`, `report-row.test.sh` on the new file and each mutant | pass on real, refuse each mutant |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | push of `dev` (owner's go) | two `test.yml` runs | 5 of 5 `success`, at most 25 min | SP-1, SP-2 |

## Constraints

- Card 1 resolved: three jobs, no matrix; the gate job pulls its own images.
- Proven only by pushed CI runs: a push of `dev` needs the owner's go each time.
- No hidden dependency between jobs: nothing in the gate reads files the suites wrote.

## Risks & Mitigation

**Risk 1: A guard goes stale and passes**
- *Risk*: a guard reads a job by name that no longer holds the step.
- *Mitigation*: AC-4 mutants per rule, run on the real new file before the push.

**Risk 2: Gate depends on images the suites pulled**
- *Risk*: the gate job fails or slows on a fresh runner.
- *Mitigation*: AC-2 reads the gate step time on a fresh runner; images are pulled in the job.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Guards in 4 files read the old layout | AC-4 | open | High |
| More runner minutes (job set-up repeated) | owner accepted | accepted-risk | Low |
