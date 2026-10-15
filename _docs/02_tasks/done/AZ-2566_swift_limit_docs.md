---
loop: 28
branch: dev
---

# Swift docs: the 6.0 limit and the CI wording

**Task**: AZ-2566_swift_limit_docs
**Name**: Swift limit docs
**Description**: ADR-005 and the README state that a Swift 6.0 consumer and an Xcode 16.0 build are unproven, and name only the runs that happened.
**Complexity**: 1 point
**Dependencies**: None
**Component**: swift_package
**Tracker**: AZ-2566
**Epic**: AZ-2223

## Problem

The README and ADR-005 say "Swift 6.0+ (Xcode 16+)" while only `swift:6.3.3` (CI) and `swift:6.4.1` (a Linux container run) were built; swift-asn1 1.7.3 needs tools 6.1. Review26 #8: the README names Linux and CI results before a run existed; Linux CI has now run.

## Outcome

- The limit sentence in the README (the language table line and the Swift section) and in ADR-005.
- Every environment named in the README Swift text maps to a recorded run or says "not built or tested".

## Scope

### Included
- `README.md` Swift lines; `_docs/02_document/adr/005_swift-installs-from-the-version-tag.md`.

### Excluded
- Pinning swift-asn1 or adding a 6.0 consumer (S3 stays B); any tag.

Feature ACs: `_docs/02_task_plans/ci-split-and-leftovers/acceptance_criteria.md`. Scenarios: `scenarios.md` in the same folder.

## Acceptance Criteria

**AC-1: Limit stated (DO-1, S-11)**
Given the README language line, the README Swift section and ADR-005
When each is read
Then each states that a Swift 6.0 consumer and an Xcode 16.0 build are unproven, the swift-asn1 1.7.3 tools-6.1 reason, and the two built toolchains (3 of 3 places, 0 claims of a tested 6.0)

**AC-2: Claims match runs (DO-2)**
Given the README Swift text
When each environment named (Linux, CI image, platform minimums) is checked against the status report
Then 0 unsupported claims and 0 mentions of `swift:5.9`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | grep for the limit phrase in the 3 places | 3 of 3 |
| AC-2 | grep `swift:5.9` | no match |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | repo at the commit | read the three places | limit present | DO-1 |

## Constraints

- Docs only; `publish-check.py` and guards that read README text still pass.

## Risks & Mitigation

**Risk 1: A guard reads the README wording**
- *Risk*: a publish check greps a README sentence.
- *Mitigation*: run `publish-gate.test.sh` readme-related checks (step 11).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Whether to prove 6.0 instead (S3 A) | owner chose B | accepted-risk | Low |
