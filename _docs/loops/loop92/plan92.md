# Autodev Loop Plan — Loop 92

loop: 92
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done: AZ-3452 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 5 points, one task |
| implement | 10 | Implement | yes | AZ-3452 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | yes | new embedded blackbox scenario (AVR run) |
| update-docs | 13 | Update Docs | yes | `cpp/embedded` entry of `module-layout.md` and the README sentence change |
| security | 14 | Security Audit | no | no auth, secret, network exposure or untrusted input touched |
| performance | 15 | Performance Test | no | no latency NFR; the stage time is measured in the task |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic change |
| retrospective | 17 | Retrospective | yes | complexity 5 |
| local-deploy | — | Local deploy + open site | yes | always at close (no app: the `cpp-embedded` compose service is the run) |
| smoke | — | Smoke acceptance | yes | always at close; user checklist in `smoke92.md` |

## Implementation

Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

### Files that change
`cpp/embedded/Dockerfile` (emulator package), `cpp/embedded/arm.sh` (`target_avr_uno`: run and check), new files under `cpp/embedded/avr/` (C harness, C++ shim), `README.md`, `cpp/embedded/run.sh` header comment if it names the row.

### Proof
Real `cpp-embedded` compose run (rebuilt image): the row passes with the sizes, 114 of 114, 9 of 9 twice and 5 of 5 in its log; the same with one injected defect (row fails); emulator removed (row fails naming it); `lib.test.sh` and `run-parts.test.sh` unchanged.

### Risks
The run may show a defect in `chacha20_xor`: stop and report.
