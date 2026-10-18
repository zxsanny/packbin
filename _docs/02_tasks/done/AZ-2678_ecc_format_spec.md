---
loop: 38
branch: dev
---

# Message ECC: contract, ADR 007 and format parameters

**Task**: AZ-2678_ecc_format_spec
**Name**: Message ECC: contract, ADR 007 and format parameters
**Description**: Fix the protected-message format in a contract and an ADR before any package codes it.
**Complexity**: 5 points
**Dependencies**: None
**Component**: library (docs)
**Tracker**: AZ-2678
**Epic**: AZ-2677

## Problem

The format of a protected message (which bytes are parity, how n and t behave, which errors exist) is only in the intake notes. Eight packages need one written contract. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17).

## Outcome

- `_docs/02_document/contracts/library/message-ecc.md` exists, version 1.0.0, and states: field GF(256) with polynomial 0x11D, generator roots alpha^0 to alpha^(n-1) with alpha = 2, parity after the clear message, n from 0 to 32, block at most 255 bytes, t from 0 to n/2 chosen by the caller, the error kinds, the repaired count, dispatch rule, session rule, in-place rule for C++
- The table of EC-15 (chance that a random buffer of the fixture's length is accepted for n = 1, 2, 4, 8, 16 and every t) is computed, not estimated
- ADR 007 is Accepted and `architecture.md` principle "the bytes are only the fields" says protected schemes are the one exception

## Scope

### Included
- The contract, ADR 007, the principle line in `architecture.md`, `pack-session.md` (protected payload = clear length + n), `interaction-risks.md` (new rows for the type-byte, truncation and garbage risks)
- Error kind names fixed per package family

### Excluded
- Any package code
- README and component descriptions (AZ-2690)

## Acceptance Criteria

**AC-1: Contract complete**
Given the contract file
When a reader implements it with no other document
Then EC-2 vectors rows 2 to 6 are reproducible from it alone (checked by AZ-2679's reference script reading only the contract's parameters).

**AC-2: Miscorrection table**
Given n in 1, 2, 4, 8, 16 and every t from 0 to n/2
When the table is read
Then each chance is computed from the code parameters and the fixture length (EC-15), 5 values of n present.

**AC-3: Rules stated**
Given the contract
When the rules for n above 32, a clear message above 254 - n bytes, a mixed-n dispatch, a protected session and a writable C++ buffer are looked up
Then each has one sentence with its error kind (EC-3, EC-4, EC-10, EC-16, EC-17).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | reference script from the contract's parameters | rows 2 to 6 reproduced |
| AC-2 | table values vs a recomputation | equal |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | contract only | encode the fixture for n = 2, 4 | bytes equal rows 3, 4 | EC-2 |
| AC-3 | contract text | grep each rule | 5 rules found | EC-3,4,10,16,17 |

## Constraints

- Wire parameters are fixed here; changing them later is a wire break after the first tag
- Decisions 1 to 5 of problem.md

## Risks & Mitigation

**Risk 1: Parameters chosen too early**
- *Risk*: the first tag is not published, so a change is still free, but eight packages follow.
- *Mitigation*: the vectors task proves the parameters with a reference decoder before any package starts.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |

## Contract

This task produces the contract at `_docs/02_document/contracts/library/message-ecc.md`. Consumers MUST read that file, not this spec.
