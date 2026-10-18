---
loop: 38
branch: dev
---

# Message ECC: reference implementation and shared vectors

**Task**: AZ-2679_ecc_reference_vectors
**Name**: Message ECC: reference implementation and shared vectors
**Description**: A reference encoder and decoder plus the golden protected bytes every package must match.
**Complexity**: 3 points
**Dependencies**: AZ-2678_ecc_format_spec
**Component**: fixtures / scripts
**Tracker**: AZ-2679
**Epic**: AZ-2677

## Problem

Eight packages need the same bytes and the same corruption cases. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17).

## Outcome

- `scripts/ecc/` holds a reference encoder, syndrome check and decoder (Python, standard library only) written from the contract
- `fixtures/ecc/vectors.txt` holds rows 1 to 14 of the results report, with a checker script and a self-test

## Scope

### Included
- Reference script, vectors file, checker, self-test, README line for the fixtures folder

### Excluded
- Package code
- CI wiring (AZ-2689)

## Acceptance Criteria

**AC-1: Golden bytes**
Given the position fixture and n = 0, 1, 2, 4, 8, 16
When the reference encodes it
Then the bytes equal rows 1 to 6 of the results report (EC-2).

**AC-2: Corruption cases**
Given rows 7 to 11 of the report
When the reference decodes them with the stated n and t
Then it returns the stated row or the stated error (EC-5, EC-6, EC-8).

**AC-3: Counts**
Given seeded generators
When the reference runs 20,000 corruptions of 1 to 4 bytes with n = 4, t = 0 and 200,000 garbage buffers with n = 2, t = 0
Then accepted corruptions are 0 and accepted garbage is at most 12 (EC-6, EC-7).

**AC-4: Truncation**
Given n = 4, t = 0 and 10,000 seeded truncations or extensions of 1 to 3 bytes
When decoded
Then wrong rows returned are 0 (EC-14).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | encode rows 1 to 6 | equal |
| AC-2 | decode rows 7 to 11 | stated outcome |
| AC-3 | seeded counts | 0 and at most 12 |
| AC-4 | truncation cases | 0 wrong rows |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | fixture | checker on vectors.txt | passes | EC-2 |
| AC-3 | seed 1 | counts | within bound | EC-6,7 |

## Constraints

- Standard library only; seeds fixed so the counts reproduce

## Risks & Mitigation

**Risk 1: Reference and contract drift**
- *Risk*: the reference is the only place the parameters run.
- *Mitigation*: the checker reads the parameters from `fixtures/ecc/vectors.txt` header; AZ-2678 AC-1 is the cross-check.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |
