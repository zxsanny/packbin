---
loop: 24
branch: dev
---

# Go PackSession matching C#

**Task**: AZ-2445_go_session
**Name**: Go PackSession matching C#
**Description**: Go `PackSession` gives C#'s ciphertext for the same seed, value and row, per the pack-session contract.
**Complexity**: 3 points
**Dependencies**: AZ-2440
**Component**: go
**Tracker**: AZ-2445
**Epic**: AZ-2222

## Problem

Go services that talk to a C# or browser peer over the encrypted session need the same stream (contract `_docs/02_document/contracts/library/pack-session.md` v1.0.0).

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-6; scenario S12).

## Outcome

- Same seed (bytes 1..32), 16-byte value `01` + 15 zero bytes and the AC-1 row give ciphertext `b55d0a29c56c203712b241232e`.
- Session AC-2 to AC-7 hold.

## Scope

### Included

- `PackSession` load/start/join/pack/unpack per the contract: HKDF-SHA256 (IKM seed, salt the 16 bytes, info `packbin`, 64 bytes), per-direction keys, counter nonce little-endian, ChaCha20 (RFC 8439) block counter 0, XOR only; the seed wiped after use. stdlib `crypto/hkdf` and `golang.org/x/crypto/chacha20` (G-3).
- Owns (exclusive write): `go/**`

### Excluded

- The session ring (AZ-2449)

## Acceptance Criteria

**AC-1: C# ciphertext**
Given seed bytes 1..32, value `01000000000000000000000000000000`, the AC-1 row
When the opener packs
Then the bytes are `b55d0a29c56c203712b241232e`

**AC-2: Session criteria**
Given session AC-2 to AC-7 (`_docs/02_task_plans/pack-session/acceptance_criteria.md`)
When run in Go
Then each holds: round trip both ways, a second packet, two clients differ, 0 sessions from a 31-byte seed or 15-byte value, pack before start/join fails

**AC-3: Hostile session input**
Given the TypeScript `session` test rows and the hostile session rows of the other packages
When run in Go
Then error values; panics 0

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | C# vector | exact hex |
| AC-2 | session AC-2..7 | hold |
| AC-3 | hostile session | errors, no panic |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | ring `pack-session`, session ring (AZ-2449) | Go in the ring | C# ciphertext | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Dependency**
- *Risk*: `golang.org/x/crypto` is the only module dependency.
- *Mitigation*: Pin one version in `go.sum`; GO-11 counts direct requirements (x/crypto only; `go mod tidy` may add `golang.org/x/sys // indirect`, allowed) and the modules of built packages in CI (`run-suite.sh go`).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
