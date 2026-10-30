# Autodev Loop Plan — Loop 89

loop: 89
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done: AZ-3443 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-3443 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | CI tooling; no product AC or scenario changed |
| update-docs | 13 | Update Docs | no | no public contract or module doc changed |
| security | 14 | Security Audit | no | no auth, secret, network exposure or untrusted input touched |
| performance | 15 | Performance Test | no | AC-4 is CI wall time, read from the CI run |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic change |
| retrospective | 17 | Retrospective | yes | loop 88 record: next retro due after loop 89 |
| local-deploy | — | Local deploy + open site | yes | always at close (no app: CI tooling, the compose `rust` service is the run) |
| smoke | — | Smoke acceptance | yes | always at close; user checklist in `smoke89.md` |

## Implementation

Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

### Files that change
`.github/workflows/run-suite.sh` (component step, `cargo clippy --lib --tests` in `rust_test_build`), `run-suite.test.sh` (expected calls, step count 22), new `run-suite-rust-clippy.test.sh` (missing component).

### Proof
Shell test, real `rust` compose run (AC-1), the same with an injected lint (AC-2); AC-4 from the first CI run.
