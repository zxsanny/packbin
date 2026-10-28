# Autodev Loop Plan — Loop 79

loop: 79
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done by P0 `/problem` + `/new-task`; specs AZ-3356, AZ-3357 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points in two tasks (3 + 2), no handoff |
| implement | 10 | Implement | yes | AZ-3356 and AZ-3357 in parallel (disjoint files: ring drivers and scripts vs `rust/` and `run-suite.sh`) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh --all`, one total run |
| test-spec-sync | 12 | Test-Spec Sync | no | no package behavior or blackbox scenario of the packages changes; the ring and suite runner are test infrastructure |
| update-docs | 13 | Update Docs | no | no public contract; `fixtures/frame/README.md` is edited by AZ-3356 |
| security | 14 | Security Audit | yes | `lite`: CI test scripts and the suite runner change |
| performance | 15 | Performance Test | no | stage time bounds are loop AC-12 |
| deploy | 16 | Deploy | no | no ship |
| release | 16.5 | Release | no | no ship |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | due: 5 loops since the last (loop 74) |
| local-deploy | — | Local deploy + open site | yes | at close: no UI, the ring, driver script and Rust builds are the smoke |
| smoke | — | Smoke acceptance | yes | `smoke79.sh` + checklist |

## Implementation

### Files that change
AZ-3356: the 8 frame drivers under `.github/workflows/drivers/`, `fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`, `scripts/frame/ring_frame.py`, `.github/workflows/ring-frame-drivers.test.sh`, `.github/workflows/ring-frame.test.sh`.
AZ-3357: `rust/src/nostd/frame/mod.rs`, `rust/src/session_core/hkdf.rs`, `rust/src/session_core/pad.rs`, `rust/tests/nostd_support/hostile.rs` and its 3 users, `.github/workflows/run-suite.sh`, `.github/workflows/run-suite.test.sh`.

### Order of work
1. Two workers at once (disjoint files), parent keeps tracker, review, commit.
2. Parent: real ring and driver script on the Mac, container builds (gcc:16, swift:6.3.3, golang:1.27), AC-3 and AC-10 proofs in scratch copies, compose `rust` stage.

### Proof
Real ring (`refusals <lang>: 43 rows, 0 mismatched` x 8), driver script 132 checks, 0 warnings in the 4 Rust builds, step 11 total run, CI on `dev` before `main`.

### Risks
Eight drivers at once (loop 77 red push): each built on its CI toolchain before the commit.

### Diverged in batch 1
- `rust/src/session_core/counters.rs`: `take` warned in the default set (the intake probe had not built it); `#[cfg(feature = "frame")]` added by the parent.
- The build step of AZ-3357 runs `cargo check --tests`, not `cargo test --no-run`: cold on 4 CPUs the Rust suite took 185 s on HEAD, 249 s with `--no-run` and 193 s with `check`, on `suites (csharp rust)`, the longest CI job (286 s).
- The Java driver answers `BadValue` itself for an epoch above `Integer.MAX_VALUE` (the Java package's epoch is an `int`); owner question at the assessment.
