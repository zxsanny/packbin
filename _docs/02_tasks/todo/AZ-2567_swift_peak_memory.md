---
loop: 28
branch: dev
---

# Swift: peak memory of the max-slots unpack

**Task**: AZ-2567_swift_peak_memory
**Name**: Swift peak memory
**Description**: The peak resident memory of the Swift unpack of the F10 packet and the default-limit wide round is measured and recorded.
**Complexity**: 2 points
**Dependencies**: None
**Component**: swift_package
**Tracker**: AZ-2567
**Epic**: AZ-2223

## Problem

Go has measured figures (625 MB and 94 MB) for the max-slots unpack; Swift has none (review26 #5), so a memory blow-up like F41 would not be seen.

## Outcome

- Two figures (MB) with the command, beside the Go figures.

## Scope

### Included
- Measure with `/usr/bin/time -l` on the Mac (and in `swift:6.3.3` if it fits in 30 minutes); a throwaway driver in the scratchpad; the entry in the security folder or status report.

### Excluded
- Fixing a high figure (opened as a finding); a permanent bounded test.

Feature ACs: `_docs/02_task_plans/ci-split-and-leftovers/acceptance_criteria.md`. Scenarios: `scenarios.md` in the same folder.

## Acceptance Criteria

**AC-1: Figures recorded (PM-1, S-10)**
Given the F10 packet and the default-limit wide round
When each is unpacked once in a release build
Then 2 of 2 maximum-resident-set figures are recorded in MB with the command, next to Go's 625 MB and 94 MB

**AC-2: High figure is a finding**
Given a figure above 1 000 MB
When it is recorded
Then a finding is opened with the figure; none is fixed in this loop

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the measurement run | 2 figures printed |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | release build on Mac | `/usr/bin/time -l` per case | figure in MB | PM-1 |

## Constraints

- Check load and swap before measuring; a loaded host does not change peak RSS but does slow the run.
- The scratch driver stays out of the repository.

## Risks & Mitigation

**Risk 1: Mac and Linux figures differ**
- *Risk*: the allocator differs.
- *Mitigation*: record the host; run the container if time allows.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Packet F10 definition lives in the loop 26 security notes | read before measuring | open | Low |
