---
loop: 97
branch: dev
---

# Parity percentage: README, component docs, module layout and glossary

**Task**: AZ-3509_parity_percent_docs
**Name**: Parity percentage: README, component docs, module layout and glossary
**Description**: Tell users and maintainers about the parity percentage in each package's own spelling.
**Complexity**: 3 points
**Dependencies**: AZ-3500_parity_percent_python, AZ-3501_parity_percent_typescript, AZ-3502_parity_percent_csharp, AZ-3503_parity_percent_java, AZ-3504_parity_percent_go, AZ-3505_parity_percent_swift, AZ-3506_parity_percent_rust, AZ-3507_parity_percent_cpp
**Component**: README and `_docs/02_document` (components, module-layout, glossary)
**Tracker**: AZ-3509
**Epic**: none

## Problem

Once the packages take a percentage, the README error-correction section still says every scheme declares a fixed count, and the component docs, module layout and glossary do not name the new setting.

## Outcome

- The README error-correction section shows the percentage beside `with_parity(n)` for each of the eight packages, with the rule "25 % of 40 bytes = 10 parity bytes", the cap of 32 and the largest message per percentage.
- Component docs, module layout (Public API rows) and glossary name the setting.

## Scope

### Included
- README text and one example per package where the section has one; tests that pin README blocks (`ReadmeExampleTests.swift`, `scripts/frame/readme-examples.sh`, the C# and Python README-pinning tests) stay true.
- `_docs/02_document` component descriptions of the eight packages, `module-layout.md`, `glossary.md`, `system-flows.md` only if a flow names parity.

### Excluded
- Any source change, the contract and ADR (AZ-3499), release notes.

## Acceptance Criteria

Plan, wording and figures: `_docs/02_task_plans/parity-percent/acceptance_criteria.md` (AC numbers there are noted in brackets), `_docs/02_task_plans/parity-percent/input_data/expected_results/results_report.md` and `_docs/02_task_plans/parity-percent/scenarios.md`.

**AC-1: README** [AC-14]
Given the README error-correction section
When it is read
Then it names the percentage in each package's spelling exactly as implemented, gives the rule and the cap, links contract 1.1.0, and every README code block that is pinned by a test still matches that test

**AC-2: Docs**
Given the component descriptions, `module-layout.md` and `glossary.md`
When they are read
Then each of the eight components lists the new setting among its public API and the glossary defines "parity percentage"

**AC-3: Nothing else changes**
Given the diff
When read
Then it touches documents and the tests that pin README blocks only

## Non-Functional Requirements

**Performance**
- Unpack adds at most 255 integer steps to find the clear length; the existing timing checks (load-factor helpers) pass unchanged.

**Compatibility**
- A fixed-count scheme writes the same bytes as in 0.4.0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the README-pinning tests of the packages and `scripts/frame/readme-examples.sh` | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | README | spelling in the table equals the shipped API of each package | equal | Compatibility |

## Constraints

- The spelling is read from the merged packages, not from the proposals in the other task specs.
- A README Swift block that is not a snippet of `ReadmeExampleTests.swift` breaks `readme_swiftBlocks_areTheSnippets` (`_docs/AGENT_GOTCHAS.md`, loop 71): run the Swift suite after the README edit.

## Risks & Mitigation

**Risk 1: README says one spelling, package ships another**
- *Risk*: a proposed name changed during implement.
- *Mitigation*: this task runs after the package tasks and reads the code.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Spelling drift | read from code | open | Low |
