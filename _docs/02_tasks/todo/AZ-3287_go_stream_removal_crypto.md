---
loop: 74
branch: dev
---

# Go without the stream session; crypto kept and verified

**Task**: AZ-3287_go_stream_removal_crypto
**Name**: Remove `PackSession` from the Go package; keep HKDF, HMAC, SHA-256 and ChaCha20 behind an internal helper on the 27 crypto rows
**Description**: Go has no stream session; its crypto is ready for the frame port.
**Complexity**: 3 points
**Dependencies**: AZ-3280_ring_ci_stream_removal
**Component**: 07_go_package
**Tracker**: AZ-3287
**Epic**: AZ-3199

## Problem

`go/session.go` is the stream session (ADR-009). It is the package's only user of `golang.org/x/crypto/chacha20` and of the standard HKDF; the frame port (loop 75) needs them (D2), and none is checked against `fixtures/crypto/vectors.txt`.

## Outcome

- 0 exported stream-session names; an unexported crypto helper passes 27 of 27 crypto rows; the module keeps `golang.org/x/crypto` and adds nothing.

## Scope

### Included
- Delete `session.go`, `session_test.go`, `session_concurrent_test.go`, `session_hostile_test.go`, and the two `ring_session_*` fuzz seeds.
- An unexported crypto helper (SHA-256, HMAC-SHA256, HKDF-SHA256 from the standard library; ChaCha20 block and XOR from `x/crypto`) with a test that reads all 27 rows of `fixtures/crypto/vectors.txt`.
- `doc.go` (the "Encrypted session" section and the ECC session lines), `module_test.go`, `ecc_scheme_test.go`, `nil_scheme_test.go`, `example_test.go` (non-session halves kept).
- `fixtures/hostile/fuzz/go/`: delete `session_edges.go`, the session parts of the others.

### Excluded
- Frame mode itself (AZ-3293, loop 75); README (AZ-3291); the Go ring driver (AZ-3280).

## Acceptance Criteria

**AC-1: No stream session**
Given the Go module
When `go doc -all` is listed and `git grep -n PackSession go fixtures/hostile/fuzz/go` runs
Then 0 exported session names and 0 hits

**AC-2: Crypto verified**
Given `fixtures/crypto/vectors.txt`
When the new test runs
Then 27 of 27 rows pass, and a row with one changed hex digit fails (1 of 1 mutant caught)

**AC-3: Suite green, dependencies**
Given `golang:1.27` (`gofmt -l`, `go vet`, `go test -race`)
When it runs
Then 0 files listed, 0 vet findings, 0 failures, and `go.mod` requires no module it did not require at HEAD

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `go doc -all`, the grep | 0 names, 0 hits |
| AC-2 | crypto vector test plus mutant | 27/27; mutant caught |
| AC-3 | the Go container run | 0 findings, 0 failures |

## Constraints

- Go runs only in `golang:1.27` (not installed on this Mac; `AGENT_GOTCHAS.md`).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The crypto helper has no caller until the frame port | owner D2 | accepted-risk | Low |
