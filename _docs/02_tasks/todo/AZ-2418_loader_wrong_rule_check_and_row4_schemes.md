---
loop: 22
branch: dev
---

# Standing wrong-rule check for the hostile loaders and row4_packed scheme check

**Task**: AZ-2418_loader_wrong_rule_check_and_row4_schemes
**Name**: Standing wrong-rule check for the hostile loaders and row4_packed scheme check
**Description**: AZ-2392 AC-2 (a loader fails when a case is given the wrong rule) was shown by temporary edits only; a standing test covers it. The TypeScript `row4_packed_*` hostile schemes are checked against the fixture README.
**Complexity**: 2 points
**Dependencies**: AZ-2417
**Component**: python, java, rust, cpp (loader tests), typescript (row4 check)
**Tracker**: AZ-2418
**Epic**: AZ-2069

## Problem

Two small gaps in the loop 21 assessment ("Not walked" and the AZ-2392 note): (1) no standing test shows that a loader fails when a case's rule-table entry is wrong; (2) `row4_packed_*` TypeScript hostile schemes pass `packed(2, ...)` where the fixture README says width 1.

## Outcome

- Each of the four loaders with a rule table has a test that feeds it one deliberately wrong rule row (in the test, not on disk) and expects failure.
- The `row4_packed_*` schemes in TypeScript match the README (width as written), or the README is corrected with the owner-visible reason in the batch report if the code is right.

## Scope

### Included
- Loader test files and `typescript/tests/hostile.test.ts` (row4 schemes), README line in `fixtures/hostile/README.md` only when it is the wrong one (parent applies it).

### Excluded
- Package sources; new hostile cases (AZ-2417).

## Acceptance Criteria

**AC-1: standing negative check**
Given a loader and a rule table with one wrong entry (built in the test)
When the loader runs
Then it fails naming that case.

**AC-2: row4 schemes agree with the README**
Given `row4_packed_*`
When compared with the fixture README
Then widths agree, or the mismatch and the decision are in the report.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | wrong-rule fixture per loader | loader reports the case |
| AC-2 | row4 widths | equal |

## Blackbox Tests

None.

## Constraints

- Test code only (plus one README line if needed); runs in the loader pass of wave 2.
