---
loop: 24
branch: dev
---

# README Go section and the seven-language wording

**Task**: AZ-2451_go_readme
**Name**: README Go section and the seven-language wording
**Description**: The README shows Go install and use; the example runs in CI and prints the README hex.
**Complexity**: 2 points
**Dependencies**: AZ-2447, AZ-2450
**Component**: go
**Tracker**: AZ-2451
**Epic**: AZ-2222

## Problem

Go users need install and usage text; the README's language lists name six.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-13).

## Outcome

- A Go section (install from the tag, typed and map pack/unpack example, session note) and Go in the supported-languages, untrusted-input and limits lists.
- The README example is a Go `Example` test whose `// Output:` is the README hex.

## Scope

### Included

- README edits; `go/example_test.go`; architecture.md components list; the Go rows in interaction-risks.md.
- Owns (exclusive write): `README.md`, `go/example_test.go`, `_docs/02_document/architecture.md`, `_docs/02_document/interaction-risks.md` (Go rows)

### Excluded

- ADR text (AZ-2450)

## Acceptance Criteria

**AC-1: Example runs**
Given the README Go example
When `go test` runs the Example
Then the output equals the README hex; mismatched bytes 0

**AC-2: Lists name Go**
Given README supported languages, Untrusted input and Limits to keep in mind
When read
Then each names Go where Go has the behavior

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | Example test | output matches |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | Go suite (AZ-2448) | `go test` | passes | GO-13 |

## Constraints

- The README states the Go differences decided in loop 24: group map rows are nested maps both ways (Go-4 A; TypeScript packs nested-or-flat and unpacks flat), a flat key naming a member of an absent group is refused, a group in a round is one map per round, typed `Times` refuses a count that differs from the slice length (as C#), `[]byte` is a byte run and never a list or a round list (a typed `[]byte` member bound to `List(U8)` works), a `Nested` row has its own name scope (member names may repeat an outer name; TypeScript refuses that for its flat group, C# allows it), a list or dict inside a lone group map given once for every round is refused, `WithLimits(Limits)` takes all three limits and refuses a value below 1 (start from `DefaultLimits()`; C#/TypeScript/Python default an omitted value), a non-bool for a bool (Go-1 B) and a whole float for an integer field (Go-2 A) are refused so a `json.Unmarshal` map needs typed rows or integer values.

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: README drift**
- *Risk*: The README example and the test can diverge.
- *Mitigation*: The test holds the same code text; the reviewer compares them.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
