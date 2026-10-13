---
loop: 24
branch: dev
---

# Go in the CI suite

**Task**: AZ-2448_go_ci_suite
**Name**: Go in the CI suite
**Description**: CI runs the Go suite on every push and pull request, in a `go` compose service on `golang:1.27`.
**Complexity**: 3 points
**Dependencies**: AZ-2440
**Component**: go
**Tracker**: AZ-2448
**Epic**: AZ-2222

## Problem

AC-11: CI must run every language's tests on 100% of pushes; Go is not in the suite.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-9, GO-11).

## Outcome

- `run-suite.sh go` checks the golden row, runs `gofmt -l`, `go vet`, `go test -race`, a 60 s fuzz step and the one-dependency check, and writes one report row.
- The scaffold job runs the `go` service with the six.

## Scope

### Included

- `run-suite.sh` `go` branch guarded by `go/go.mod`; `docker-compose.test.yml` and `docker-compose.publish.yml` `go` services (read-only mount in the publish file); the scaffold job's directory check and suite loop; `report-row.test.sh` and `run-suite.test.sh` rows for Go.
- Owns (exclusive write): `.github/workflows/run-suite.sh`, `.github/workflows/run-suite.test.sh`, `.github/workflows/test.yml` (scaffold job only), `.github/workflows/report-row.test.sh`, `docker-compose.test.yml`, `docker-compose.publish.yml`

### Excluded

- The ring job (AZ-2449)
- publish (AZ-2450)

## Acceptance Criteria

**AC-1: Suite runs**
Given a push
When the scaffold job runs
Then the `go` service runs `run-suite.sh go`; a failing Go test fails the job; `test-results/report.csv` gains one `go suite` row

**AC-2: Quality gates**
Given the Go tree
When `run-suite.sh go` runs
Then `gofmt -l` lists 0 files, `go vet` reports 0 findings, `go test -race` passes, fuzz 60 s passes, `go list -m all` shows exactly 1 non-stdlib module besides the main one

**AC-3: Absent tree**
Given a tree without `go/go.mod`
When `run-suite.sh go` runs
Then it fails as for the other languages (guarded by the manifest), proven by `run-suite.test.sh`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-3 | `run-suite.test.sh` go rows | pass |
| AC-1 | `report-row.test.sh` seven services | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `docker compose -f docker-compose.test.yml run --rm go` | the Go suite | exit 0 | AC-11 |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Shared files**
- *Risk*: `test.yml` is also edited by AZ-2449 (ring job).
- *Mitigation*: AZ-2448 edits only the scaffold job; AZ-2449 only the ring job; the parent checks the diff at each join.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
