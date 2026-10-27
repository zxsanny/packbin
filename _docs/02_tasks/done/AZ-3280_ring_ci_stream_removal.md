---
loop: 74
branch: dev
---

# Ring and CI without the stream session

**Task**: AZ-3280_ring_ci_stream_removal
**Name**: Remove the session stages from the cross-language ring, its drivers and the shared CI scripts
**Description**: The ring and CI stop calling the stream session in every package, so each package can drop it.
**Complexity**: 3 points
**Dependencies**: None
**Component**: CI and the cross-language ring (`.github/workflows/`, `scripts/`)
**Tracker**: AZ-3280
**Epic**: AZ-3199

## Problem

The ring script runs `pack-session`, `unpack-session`, `pack-session-ecc` and `unpack-session-ecc` on all 8 drivers (64 handoffs each), three wiring tests parse those stages, and the shared suite scripts name session tests of Rust and Swift. Until they change, no package can remove its session.

## Outcome

- The ring has clear and ECC stages only; every driver offers 0 session commands.
- The shared suite scripts and their self-tests name 0 session tests; the Go dependency allowlist keeps `golang.org/x/crypto` (D2).

## Scope

### Included
- `.github/workflows/language-pair.sh` (the session and session-ECC stages and their hex), `ring-wiring-rows.test.sh`, `ring-wiring-swift.test.sh`, delete `ring-wiring-session-ecc.test.sh`; the `test.yml` step "session-ecc ring wiring"; `scripts/loop-tests.sh` (its line running that test).
- The 8 ring drivers under `.github/workflows/drivers/` (session commands out; `handoff-go/session.go` and `handoff-swift/.../Session.swift` deleted; `handoff-go/go.mod`, `go.sum` tidied).
- `.github/workflows/run-suite.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh`: the Rust `nostd_session_tests` runs and the `session` feature in the cargo lines, the Swift tsan suites `SessionTests`, `SessionHostileTests`, the counts their self-tests expect.
- Stale wording: `stage-arduino.sh`, `publish-npm.test.sh`.

### Excluded
- Package sources and tests (AZ-3281 to AZ-3290); `ring-lib.sh` and `publish-position.sh` compile lines of C++ (AZ-3286); docs (AZ-3291).

## Acceptance Criteria

**AC-1: Ring without session**
Given the ring script and its 8 drivers
When the ring runs all pairs
Then the clear and ECC stages pass for 8 x 8 drivers and 0 session stages or commands exist (search for `pack-session` in `.github/workflows/` finds 0 hits)

**AC-2: Wiring tests agree**
Given `ring-wiring-rows.test.sh` and `ring-wiring-swift.test.sh`
When they run
Then both pass, and each still fails a mutant that drops a clear or ECC row (1 of 1 mutant caught each)

**AC-3: Suite scripts**
Given `run-suite.sh` and its two self-tests
When the self-tests run
Then they pass with 0 references to session tests and the cargo line count they assert equals the lines in `run-suite.sh`

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | `ring-wiring-rows.test.sh`, `ring-wiring-swift.test.sh` with their mutants | pass; mutants caught |
| AC-3 | `run-suite.test.sh`, `run-suite-swift.test.sh` | pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the ring in `docker compose` (`scripts/loop-tests.sh` ring stage) | all driver pairs | clear and ECC pass, 0 session stages | — |

## Constraints

- Runs first (coupling 1 of `feature-description.md`): it lands in the same batch as, or before, every package task.
- Before the commit, `git grep` every reader of the changed scripts and run each one (`AGENT_GOTCHAS.md`, loop 34 and 39).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ring loses its only cross-language check of the session ciphertext | ADR-009: the session is removed | resolved | Low |
