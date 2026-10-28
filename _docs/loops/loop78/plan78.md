# Autodev Loop Plan — Loop 78

loop: 78
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done by P0 `/problem` + `/new-task`; specs AZ-3354, AZ-3355 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | done inside `/new-task`: 8 points split into 5 + 3 (`feature-description.md`) |
| implement | 10 | Implement | yes | AZ-3354 then AZ-3355 (same driver files, serial) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh --all`, one total run |
| test-spec-sync | 12 | Test-Spec Sync | no | no product behavior or blackbox scenario changed |
| update-docs | 13 | Update Docs | no | no public contract; `fixtures/frame/README.md` is edited by AZ-3354 |
| security | 14 | Security Audit | yes | `lite`: CI workflow and test scripts change |
| performance | 15 | Performance Test | no | ring time bound is AZ-3354 AC-7 |
| deploy | 16 | Deploy | no | no ship |
| release | 16.5 | Release | no | no ship |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | not due (last: loop 74; next after loop 79) |
| local-deploy | — | Local deploy + open site | yes | at close: no UI, the ring and driver scripts are the smoke |
| smoke | — | Smoke acceptance | yes | `smoke78.sh` + checklist |

## Implementation

### Files that change
`fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md`, `scripts/frame/ring_frame.py`, `.github/workflows/ring-frame.sh`(if needed), `ring-frame.test.sh`, new `ring-frame-drivers.test.sh`, `test.yml`, `scripts/loop-tests.sh`, the 8 frame drivers.

### Order of work
1. AZ-3354: checker and fixture rows, `fake.py`, drivers (no abort, `out_len`), self-test cases, real ring run.
2. AZ-3355: `ring_frame.py` writer blame first, then strict drivers, Go, Python skip, driver test script and wiring.

### Proof
Real ring on the Mac (`refusals <lang>: 38 rows, 0 mismatched` x 8), driver test script (29 runs), step 11 total run, CI on `dev` before `main`.

### Risks
Eight drivers at once (loop 77 red push): run each on its toolchain before the first push.
