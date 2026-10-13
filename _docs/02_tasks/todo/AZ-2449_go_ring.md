---
loop: 24
branch: dev
---

# Go in the language-pair ring

**Task**: AZ-2449_go_ring
**Name**: Go in the language-pair ring
**Description**: Go joins each ring kind in both directions with every member, the session ring and the position check.
**Complexity**: 3 points
**Dependencies**: AZ-2445
**Component**: go
**Tracker**: AZ-2449
**Epic**: AZ-2222

## Problem

The ring proves bytes cross languages; GO-7 and fit decision 3 put Go in every kind both ways.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-7; scenarios S1, S7).

## Outcome

- A Go driver implements the driver contract (`pack-<kind>`, `unpack-<kind> <hex>`, `unpack-<kind>-short <hex>`, exit 2 on an unknown command) for all 15 kinds and the session.
- Go packs and each member of a kind's ring unpacks; each member packs and Go unpacks.

## Scope

### Included

- `drivers/handoff-go/` (its own `go.mod` with a `replace` to the repo's `go/`), a position program printing the golden hex; `run_lang go`; the handoff lines; `RING_GO` and a SHA-pinned `setup-go` in the ring job; the toolchain check; `ring-wiring.test.sh` guards for the Go lines.
- Owns (exclusive write): `.github/workflows/drivers/handoff-go/**` (handoff and position programs), `.github/workflows/language-pair.sh`, `.github/workflows/ring-toolchains.sh`, `.github/workflows/ring-wiring.test.sh`, `.github/workflows/test.yml` (ring job only)

### Excluded

- publish-position (AZ-2450 consumes the position program)

## Acceptance Criteria

**AC-1: Every kind both ways**
Given the 15 kinds and each kind's ring members
When `language-pair.sh` runs
Then Go→member and member→Go handoffs pass for every kind; the `-short` kinds refused by Go with no row; failed handoffs 0

**AC-2: Session**
Given seed 1..32, value `01`+15 zero bytes
When Go `pack-session`
Then prints `b55d0a29c56c203712b241232e`; the session ring both ways passes

**AC-3: Wiring guarded**
Given a copy of `language-pair.sh` with one Go line removed
When `ring-wiring.test.sh` runs
Then it fails naming the missing line

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-3 | `ring-wiring.test.sh` | guards the Go lines |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | ring job | `language-pair.sh` | 0 failed handoffs | GO-7 |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Ring time**
- *Risk*: Go both ways with every member about doubles the ring job.
- *Mitigation*: Build the Go driver once per run (`go build` to a temp binary), as Java compiles once.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
