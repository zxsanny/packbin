---
loop: 29
branch: dev
---

# Publish gate cut: job at most 18 minutes without losing a guard

**Task**: AZ-2582_publish_gate_cut
**Name**: Publish gate cut
**Description**: The CI `publish-gate` job takes at most 18 minutes (median of 3 runs) and every guard of the gate still rejects its mutants.
**Complexity**: 5 points
**Dependencies**: AZ-2563_ci_gate_timings
**Component**: ci
**Tracker**: AZ-2582
**Epic**: AZ-2223

## Problem

The `publish-gate` job is the longest job of the CI workflow: 1 370 s as the median of the last three runs (1 144 to 1 392 s). The workflow limit set in loop 28 is 25 minutes and the job varies by about 4 minutes, so the margin is thin. The gate prints one timing line per group (swift 284 s, readonly 263 s, phases 251 s, gate 191 s of 1 059 s on the Mac) but nothing below the group, so no cut is justified by evidence yet.

## Outcome

- The job takes at most 1 080 s as the median of 3 CI runs, none above 1 200 s.
- The timed groups add up to at most 800 s on the Mac.
- Seconds per scenario for the four large groups are recorded before the first cut, and each cut names the scenario and the seconds it saves.
- No assertion and no mutant is lost.

## Scope

### Included
- Measure the four large groups per scenario or command; remove repeated work and share read-only state built once per run.
- A mutant for every changed scenario; the new gate timings in the CI documentation.

### Excluded
- The `suites` job split, running the gate in parallel on the Mac, changing `test.yml` jobs, product code, tags, registry uploads.
- Review items 28 #3 and #4, and AZ-2068.

## Acceptance Criteria

Feature acceptance criteria GC-1 to GC-10 of `_docs/02_task_plans/gate-cut/acceptance_criteria.md` are the criteria of this task (numeric targets there). Scenarios S1 to S8 map in `scenarios.md`.

**AC-1: Speed (GC-1, GC-2, GC-3)**
Given the final gate code is pushed
When 3 CI runs of it finish
Then the `publish-gate` job median is at most 1 080 s, none above 1 200 s, the Mac timed sum is at most 800 s, and the workflow end to end is at most 1 371 s in the median.

**AC-2: Nothing lost (GC-4, GC-5)**
Given the gate log before the change
When the gate runs after the change
Then each of the 14 groups has equal or more assertions and mutants, and each changed scenario has a mutant the gate rejects with the group's own message.

**AC-3: Isolation (GC-9, S2, S3, S4)**
Given shared state built once per run
When the gate runs twice at once, or is aborted midway
Then both runs pass, and 0 directories of the run are left.

**AC-4: Format and size (GC-6, GC-10, S8)**
Given the changed files
When size, lint and the timing selftest run
Then each file is at most 500 lines, `shellcheck` shows 0 new warnings, and the 14 timing line names and format are unchanged.

**AC-5: Evidence and docs (GC-7, GC-8)**
Given the work is done
When the status report and the CI document are read
Then per-scenario seconds for the four large groups, the cut list with seconds saved (within 20 % of the measured gain), and the median of 3 runs are present, with 0 loop 28 figures left as current.

## Non-Functional Requirements

**Performance**
- Targets above (runner and Mac).

**Compatibility**
- Runs on the Mac (arm64, Bash 3.2 and Homebrew tools) and on `ubuntu-latest`; a missing tool still prints NOT RUN.

**Reliability**
- A cut never turns a guard into a pass: shared state is read-only for scenarios that a mutant needs fresh.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | Each changed scenario against a mutated copy | gate exits non-zero with the group's message |
| AC-3 | Two gate runs at once; one run killed midway | both pass; temp directories of the run absent |
| AC-4 | `publish-timing.selftest.sh`, `wc -l`, `shellcheck` | pass; at most 500 lines; 0 new warnings |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | Pushed `dev` and `main` commits with the final code | Jobs API times of 3 runs | median at most 1 080 s | Performance |
| AC-2 | Loop 28 gate log | Counts per group before and after | equal or higher in all 14 | Reliability |
| AC-5 | Finished loop | Status report and `ci_cd_pipeline.md` | figures present | — |

## Constraints

- Card 1 (resolved, A): scenarios share only read-only fixtures built once per run under the run's own temp directory; every mutant keeps its own copy.
- No change to `test.yml` job layout (approach A, owner 2026-10-15); a split is decided only if the 3 runs miss the target.

## Risks & Mitigation

**Risk 1: A shared fixture hides a guard**
- *Risk*: a mutant passes because the fixture it breaks is not the one the scenario reads.
- *Mitigation*: one mutant per changed scenario, run before and after; counts compared per group.

**Risk 2: The Mac gain does not move the runner**
- *Risk*: image pulls and cold caches dominate on `ubuntu-latest`.
- *Mitigation*: judge by the 3 CI runs only; if short of the target, report the gap and put approach B to the owner.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Sharing state can let a mutation proof pass for the wrong reason | one mutant per changed scenario, counts compared | resolved (card 1, A) | High |
| The gain is proven only by pushed runs; pushes of `dev` are asked each time (loop 28 close commit also unpushed) | owner | open | Medium |
| Runner time varies about 4 minutes between runs | median of 3 | open | Medium |
| Mac and runner differ | judge by CI runs | open | Medium |
| No tag, no registry upload | owner | resolved | — |
