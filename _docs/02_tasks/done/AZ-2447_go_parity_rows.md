---
loop: 24
branch: dev
---

# Go parity rows: TypeScript's U-row and AC-3 tables

**Task**: AZ-2447_go_parity_rows
**Name**: Go parity rows: TypeScript's U-row and AC-3 tables
**Description**: Go pins every cross-package parity row TypeScript pins (U1 to U26 that apply, AC-3 tables).
**Complexity**: 3 points
**Dependencies**: AZ-2446
**Component**: go
**Tracker**: AZ-2447
**Epic**: AZ-2222

## Problem

Parity across loops 17 to 23 lives in TypeScript test tables and the reference docs; without them Go can drift on rows no single-kind test covers.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-3).

## Outcome

- Every row of `loop20-parity-pins`, `loop21-parity-probes`, `loop23-bigint-count` (as the five for U6), `flags-when-member` AC-3 table, `flag-group-presence`, `bool-flag`, `fields`, `packbin` and `blackbox-tests-16-loop23-parity-rows.md` gives TypeScript's hex or refusal in Go.

## Scope

### Included

- Go test files porting those tables; a row list in the batch report naming any row Go cannot express.
- Owns (exclusive write): `go/**` (tests only; a walker fix found here is reported to the parent)

### Excluded

- Walker changes (reported to the parent and opened as a Bug, as AZ-2437)

## Acceptance Criteria

**AC-1: Parity tables**
Given the rows listed in Outcome
When run in Go
Then hex mismatches 0; refusal-vs-bytes disagreements 0; every refusal names the field id (and the count where there is one)

**AC-2: U6 follows the five**
Given a `times` count given as an integer above 2^53
When packed in Go
Then the outcome of the five (refused or packed as C#, Python, Rust, Java), not TypeScript's split

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | ported parity rows | TypeScript outcome |
| AC-2 | U6 row | the five's outcome |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | ring (AZ-2449) | Go handoffs | pass | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: A real disagreement**
- *Risk*: Go may follow the spec text where TypeScript is the outlier.
- *Mitigation*: Report to the parent; the owner decides (lesson 2026-10-11: one cross-package table in front of the owner).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
