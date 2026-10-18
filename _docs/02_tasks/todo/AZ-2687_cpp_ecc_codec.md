---
loop: 38
branch: dev
---

# Message ECC: C++ allocation-free codec

**Task**: AZ-2687_cpp_ecc_codec
**Name**: Message ECC: C++ allocation-free codec
**Description**: The C++ core codec: encode, syndrome check and repair with no heap and no exceptions.
**Complexity**: 5 points
**Dependencies**: AZ-2679_ecc_reference_vectors
**Component**: cpp package
**Tracker**: AZ-2687
**Epic**: AZ-2677

## Problem

The C++ core is allocation-free and exception-free and sits in a 60-byte flash margin on Cortex-M4F. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17).

## Outcome

- Parity encode, syndrome check and repair up to t bytes in `cpp/include/packbin/` with fixed buffers
- `PACKBIN_NO_ECC` removes the repair path (and the encode path where selected) from a build

## Scope

### Included
- New header(s) and tests for the codec only, `cpp/tests/`

### Excluded
- Scheme setting, pack/unpack API, session, dispatch, embedded size gates (AZ-2688)

## Acceptance Criteria

**AC-1: Bytes**
Given the position fixture and n = 1 to 16
When encoded
Then the bytes equal rows 2 to 6 (EC-2).

**AC-2: Repair and refusal**
Given rows 7 to 11 and the seeded cases of EC-5, EC-6
When checked and repaired
Then results equal the report; wrong rows 0 (EC-5, EC-6, EC-8).

**AC-3: Speed**
Given a 254-byte message with 16 parity bytes and 8 wrong bytes
When repaired 1,000 times
Then within 1 s on one core (EC-13).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | encode rows 2 to 6 | equal |
| AC-2 | repair and refuse | as stated |
| AC-3 | speed loop | <= 1 s |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | host build | codec against the vectors | passes | EC-5,6 |

## Constraints

- No heap, no RTTI, no exceptions, no global mutable state (core rule)
- Stack use of the repair path is bounded and measured

## Risks & Mitigation

**Risk 1: Stack on small targets**
- *Risk*: repair working arrays.
- *Mitigation*: fixed sizes from n <= 32; the number is recorded for AZ-2688.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |
