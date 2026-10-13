---
loop: 24
branch: dev
---

# Go release: ADR-004, golden gate, go/vX.Y.Z tag and proxy check

**Task**: AZ-2450_go_release
**Name**: Go release: ADR-004, golden gate, go/vX.Y.Z tag and proxy check
**Description**: A version tag whose seven languages match the golden bytes gets a `go/vX.Y.Z` tag at the same commit and a proxy fetch check; a mismatch gets none.
**Complexity**: 5 points
**Dependencies**: AZ-2448, AZ-2449
**Component**: go
**Tracker**: AZ-2450
**Epic**: AZ-2222

## Problem

Go has no registry; it is fetched from a tag (G-1, G-6). ADR-002 names six packages (fit decision 1) and its gate is all-or-nothing (fit decision 2).

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-10, GO-16; scenarios S9, S10, S11).

## Outcome

- ADR-004 (Accepted) amends ADR-002's count: Go ships as `go/vX.Y.Z` at the `vX.Y.Z` commit, after the same golden gate.
- `publish.yml` pushes the Go tag only after the gate and checks `go list -m github.com/zxsanny/packbin/go@vX.Y.Z` through proxy.golang.org.

## Scope

### Included

- `language_present go` (`go/go.mod`); Go in `PACKBIN_LANGS` and the gate (publish-position.sh `go` via the AZ-2449 position program in the `go` compose container); a `go-tag` target: push `go/vX.Y.Z` with the workflow token, idempotent on re-run; the proxy check with retries for up to 30 minutes; `go/LICENSE` MIT check; the publish tests (new sibling `publish-go.test.sh`; `publish-phases.test.sh` is over 500 lines and is not grown).
- Owns (exclusive write): `_docs/02_document/adr/004_*.md`, `_docs/02_document/adr/README.md`, `.github/workflows/publish.yml`, `publish-lib.sh`, `publish-gate.sh`, `publish-position.sh`, `publish-registries.sh` (go target branch), a new `publish-go.test.sh`, the six-language lists in `publish-gate.test.sh`, `publish-readonly.test.sh` (`RO_SERVICES` gains `go`: the `go` service in `docker-compose.publish.yml` exists since AZ-2448), `publish-rerun.test.sh`

### Excluded

- Pushing any real tag in loop 24

## Acceptance Criteria

**AC-1: Gate includes Go**
Given a tree where Go's position program prints a wrong byte
When `publish-gate.sh` runs
Then it prints the mismatch and publishes 0 packages and 0 Go tags

**AC-2: Tag at the same commit**
Given a passing gate for `vX.Y.Z`
When the publish runs (dry run in tests)
Then exactly one `go/vX.Y.Z` is pushed at the `vX.Y.Z` commit; then the proxy check runs

**AC-3: Re-run**
Given `go/vX.Y.Z` already at the same commit / at another commit
When the publish re-runs
Then passes without pushing / fails naming both commits

**AC-4: Absent Go**
Given a tree without `go/`
When the gate runs
Then `absent go`; 0 Go tags; the other packages publish as before

**AC-5: ADR**
Given ADR-004
When read
Then Status Accepted; it states the tag layout, the gate rule and that tags never move (bad versions are retracted)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1..4 | `publish-go.test.sh` scenarios | as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `publish-gate.test.sh` | the full gate test | passes with seven languages | AC-12, AC-14, AC-15 |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Token scope**
- *Risk*: Pushing a tag needs `contents: write`.
- *Mitigation*: The publish job already has it; the tag push step runs only after every registry upload succeeded.

**Risk 2: Proxy delay**
- *Risk*: proxy.golang.org may take minutes.
- *Mitigation*: Retry up to 30 minutes, then fail the step (the tag stays; a re-run only re-checks).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
