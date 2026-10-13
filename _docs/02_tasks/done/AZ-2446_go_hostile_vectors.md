---
loop: 24
branch: dev
---

# Go hostile vectors and the seventh package in the case checker

**Task**: AZ-2446_go_hostile_vectors
**Name**: Go hostile vectors and the seventh package in the case checker
**Description**: Go replays all 65 hostile cases with the rule each refusal must give, and the case checker counts seven packages.
**Complexity**: 3 points
**Dependencies**: AZ-2444, AZ-2445
**Component**: go
**Tracker**: AZ-2446
**Epic**: AZ-2222

## Problem

Every package proves its hostile outcomes against `fixtures/hostile/cases.txt`; the checker requires every pack section to name each package once (loop 24 fit decision 5).

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-4; scenario S2).

## Outcome

- All 65 cases pass in Go with the outcome term and the refusal rule pinned (as the TypeScript `PACK_REFUSAL` table).
- `check-cases.sh` counts seven names, whole word; all 41 pack sections name Go in `Run by` or `Not run by`.

## Scope

### Included

- A Go loader for all four stages (unpack with a 1 s guard each, construct, limit with the section's low limit, pack); the rule table and a self-test that a wrong rule entry fails; `check-cases.sh` package list plus whole-word matching; a `cases.test.sh` corruption case for the Go name; the README sections.
- Owns (exclusive write): `go/**` (loader test), `fixtures/hostile/check-cases.sh`, `fixtures/hostile/cases.test.sh`, `fixtures/hostile/README.md`

### Excluded

- New hostile cases

## Acceptance Criteria

**AC-1: All cases**
Given the 65 cases of `cases.txt`
When the Go loader runs them
Then each outcome is one of the listed terms; the refusal rule matches the table; panics 0; each unpack ≤ 1 s

**AC-2: Wrong rule fails**
Given a deliberately wrong rule entry
When the loader self-test runs
Then it fails (as the AZ-2418 self-tests)

**AC-3: Checker counts seven**
Given the committed `README.md`, and copies with Go missing, Go twice, and a reason containing "Google"
When `check-cases.sh` and `cases.test.sh` run
Then the committed file passes; missing or doubled Go fails; "Google" is not counted as Go

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | 65 cases | allowed outcome |
| AC-2 | wrong rule | fails |
| AC-3 | checker copies | pass/fail as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-3 | scaffold job | `cases.test.sh` | passes | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- A refused `limit` round is the error kind `TooMany` (Needed 0, Left as in the cases): the loader accepts `TooMany` (and `BadValue`) for `limit` cases (AZ-2444 discovery 31). `WithLimits(Limits)` takes all three limits: start from `DefaultLimits()` and set `MaxRounds` to the section's low limit.\n- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Skips**
- *Risk*: A case Go cannot express needs a `Not run by` reason.
- *Mitigation*: Go's map form can write every row TypeScript writes; a skip is reported to the parent first.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
