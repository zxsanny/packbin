---
loop: 98
branch: dev
---
# Percentage in the Swift and Go API pages

**Task**: AZ-3524_percent_docs_swift_go
**Name**: percent_docs_swift_go
**Description**: The Swift DocC page and the Go package doc describe the parity percentage next to the parity count.
**Complexity**: 2 points
**Dependencies**: None
**Component**: library docs (Swift, Go)
**Tracker**: AZ-3524
**Epic**: none

## Problem

Loop 97 gave all eight packages a parity percentage and wrote it in the README. The Swift DocC page and the Go package doc still describe only the count, so a reader of either API reference never learns the setting exists.

## Outcome

- Each of the two pages explains the percentage with the same numbers and rules as the README.
- Every name each page uses exists in its package.

## Scope

### Included
- The error-correction section of the Swift DocC page and its API list.
- The error-correction section of the Go package doc.

### Excluded
- The README and the other six packages' docs (done in loop 97).
- Any change to package behavior or signatures.

## Acceptance Criteria

**AC-1: The Swift page describes the percentage**
Given a reader of the Swift DocC page
When they read the error-correction section
Then it gives the formula `n = min(32, ceil(p x L / 100))`, the setter `withLimits(parityPercent:)` and the reader `parityPercent`, that a value outside 0 to 100 is refused as `.schemeError`, that a percentage and a count replace each other (the last one set wins), that 0 is a scheme without parity, the largest clear sizes 251 bytes at 1 %, 230 at 10 % and 222 from 25 % up, and the API list names `parityPercent` and the new `withLimits` argument; every symbol the page names exists in the Swift package.

**AC-2: The Go doc describes the percentage**
Given a reader running `go doc` on the Go package
When they read the error-correction section
Then it gives the same formula, rules and limits with `WithParityPercent(p int) (*Scheme, error)`, `ParityPercent() int` and `MaxParityPercent` (100), and `go doc` lists the three names.

**AC-3: Both pages equal the README**
Given the README section "A percentage instead of a count"
When the two pages are read against it
Then every number and rule is the same (0 differences) and the Go file still builds and vets clean.

## Non-Functional Requirements

**Compatibility**
- The Swift page keeps building as DocC (symbol links in double backticks resolve); if DocC cannot run on this host, the symbols are checked by search and the result says so.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | `go vet ./...` and `go doc` on the package | exit 0; the three names are listed |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the edited page | search the page for every backticked symbol and look each up in the Swift sources | 0 symbols missing | DocC |
| AC-3 | README section and the two pages | read side by side | 0 differences in numbers and rules | - |

## Constraints

- Wording follows the README and `glossary.md`; no new behavior is described.

## Risks & Mitigation

**Risk 1: A page states a rule the package does not keep**
- *Risk*: the docs copy a README rule that a package refuses differently.
- *Mitigation*: AC-1 and AC-2 check each named symbol and each refusal kind against the package source.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| No DocC build on this host may leave symbol links unchecked by the tool | agent; say so in the result | open | Low |
