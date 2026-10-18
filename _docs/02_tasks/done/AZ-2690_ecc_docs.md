---
loop: 38
branch: dev
---

# Message ECC: README, component descriptions and risk docs

**Task**: AZ-2690_ecc_docs
**Name**: Message ECC: README, component descriptions and risk docs
**Description**: Document the feature where readers look.
**Complexity**: 2 points
**Dependencies**: AZ-2689_ecc_ring_ci
**Component**: docs
**Tracker**: AZ-2690
**Epic**: AZ-2677

## Problem

A reader of the README or a component description cannot learn about parity bytes. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17).

## Outcome

- README section, eight component descriptions, glossary entries, risk and security notes are updated

## Scope

### Included
- README, `_docs/02_document/components/*`, `glossary.md`, `risk_mitigations.md`, `_docs/05_security/`

### Excluded
- Code

## Acceptance Criteria

**AC-1: Docs match the contract**
Given the README and the eight component descriptions
When each is searched for parity, n, t and the error kind
Then every package states the setting name, the error kind and the limits of the contract (EC-3, EC-4).

**AC-2: Risks recorded**
Given `risk_mitigations.md`
When read
Then it lists the correction/detection trade-off and the 254-byte message (flagged concerns of problem.md).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | grep over the nine docs | 9 of 9 present |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | docs folder | link check | 0 broken links | — |

## Constraints

- Docs only

## Risks & Mitigation

**Risk 1: Drift from the contract**
- *Risk*: names differ.
- *Mitigation*: copy names from the contract.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |
