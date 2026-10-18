---
loop: 38
branch: dev
---

# Message ECC: cross-language ring, hostile cases and CI

**Task**: AZ-2689_ecc_ring_ci
**Name**: Message ECC: cross-language ring, hostile cases and CI
**Description**: Prove the eight packages read each other's protected bytes and keep CI within budget.
**Complexity**: 3 points
**Dependencies**: AZ-2680 to AZ-2688
**Component**: ring / CI
**Tracker**: AZ-2689
**Epic**: AZ-2677

## Problem

Per-package tests prove one package; the ring proves all eight agree. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17).

## Outcome

- 8 writers x 8 readers over the vectors including corruption
- Hostile-case rules for the new decoders
- CI wiring that keeps the `test.yml` median near its current value

## Scope

### Included
- `scripts/`, `fixtures/ecc/`, `.github/workflows/test.yml` job wiring

### Excluded
- Package code

## Acceptance Criteria

**AC-1: Ring**
Given the vectors of AZ-2679
When each package writes and each reads
Then 64 pairs, mismatched rows 0 (EC-9).

**AC-2: Hostile**
Given truncation, extension and garbage cases
When each package reads them
Then wrong rows 0 (EC-14).

**AC-3: CI budget**
Given the new check in `test.yml`
When the run completes twice
Then the median is at most 25 s above the loop 34 median of 213.5 s (EC-13 for speed bounds).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | ring driver self-test | passes |
| AC-2 | hostile loader rule | standing test |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | all 8 packages built | ring run | 64 pairs pass | EC-9 |
| AC-3 | two CI runs | median | <= 238.5 s | EC-13 |

## Constraints

- Reuse the existing ring job; no new job unless the median budget is met

## Risks & Mitigation

**Risk 1: CI time**
- *Risk*: eight decoders in the ring.
- *Mitigation*: vectors only, no loops; speed loops stay in package suites.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |
