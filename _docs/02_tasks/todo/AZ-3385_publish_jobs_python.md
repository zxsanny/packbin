---
loop: 82
branch: dev
---

# publish-jobs.test.sh layout checker and 111 mutants in Python

**Task**: AZ-3385_publish_jobs_python
**Name**: publish-jobs.test.sh layout checker and 111 mutants in Python
**Description**: The job layout checker of `test.yml` and its 111 mutants run in Python with each mutant still refused with a message.
**Complexity**: 5 points
**Dependencies**: AZ-3381
**Component**: CI scripts (`.github/workflows/`, `test.yml`, `tool-pins.txt`)
**Tracker**: AZ-3385
**Epic**: none

## Problem

`publish-jobs.test.sh` (384 lines) embeds a 192-line checker (lines 20-211) and a mutant editor (lines 218-226) that runs a Ruby expression over the loaded workflow hash for each of 111 `mutant` calls, plus `gate_mutant` sed variants.

## Outcome

- The same layout rules, the same 111 mutants as Python edits of the loaded dict, the same refusals.

## Scope

### Included

- The checker and the mutant editor ported; the 111 expressions rewritten; `gate_mutant` and `refused` kept.
- Split by responsibility so each file is at or under 500 lines (checker, mutants).

### Excluded

- `publish-gate.test.sh` and its groups.
- Changes to the layout rules.

## Acceptance Criteria

**AC-1: Real file passes**
Given `test.yml` at HEAD
When the ported checker runs
Then exit 0 and `job layout of test.yml: ok`

**AC-2: Every mutant is refused**
Given the 111 mutants of HEAD, each as a Python edit
When the checker runs on each changed copy
Then 111 of 111 exit non-zero with a message (0 refused silently, 0 accepted)

**AC-3: No Ruby**
Given a host with no `ruby`
When the script runs
Then exit 0 and no `ruby` text in the output

## Non-Functional Requirements

**Compatibility**
- Runs with `python3 -I` on the Python of this host (3.14.4) and of the CI jobs; uses only features both have.

**Reliability**
- A reader failure is a failure of the script that called it; no script goes on with an empty value.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | real `test.yml` | ok |
| AC-2 | 111 mutants | 111 refused |
| AC-3 | no ruby | exit 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | this host | `bash publish-jobs.test.sh` | passes with `layout check rejects:` for all 111 | - |

## Constraints

- No stand-in: every check of the replaced script is kept (label list taken from the source at HEAD 5a78fb8 before the change); a check that cannot be kept goes to the owner, never dropped.
- Each ported script is proven by one deliberate mutation of what it guards (it exits non-zero and names the check) and runs green on a host without `ruby`.
- Each file stays at or under 500 lines; split by responsibility.
- Inherits project AC-11, AC-12, AC-14, AC-15 unchanged in meaning.
- One mutant that a Python edit cannot express in the same way is reported with the reason; it is not dropped.

## Risks & Mitigation

**Risk 1: volume**
- *Risk*: 111 hand-ported expressions; a mutant that no longer changes the file passes unnoticed.
- *Mitigation*: the runner keeps a check that each edited copy differs from `test.yml` (as `gate_mutant` does with `cmp`).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A ported mutant edits nothing and the layout check still passes | compare the copy with the original | open | Medium |
