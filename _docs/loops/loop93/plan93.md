# Autodev Loop Plan — Loop 93

loop: 93
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done: AZ-3469 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-3469 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | yes | the M33F embedded scenarios gain a window check and two failure runs |
| update-docs | 13 | Update Docs | yes | script header, `lib.sh` comment and README sentence change |
| security | 14 | Security Audit | no | no auth, secret, network exposure or untrusted input touched |
| performance | 15 | Performance Test | no | no latency NFR; stage time measured in the task |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | no data store or traffic change |
| retrospective | 17 | Retrospective | no | 3 points, no incident, last retro loop 92 (next due after loop 97) |
| local-deploy | — | Local deploy + open site | yes | always at close (no app: the `cpp-embedded` and `rust-embedded` compose services are the run) |
| smoke | — | Smoke acceptance | yes | always at close; user checklist in `smoke93.md` |

## Implementation

Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

### Files that change
`cpp/embedded/arm/mps2-an505.ld` (RAM length, header), `cpp/embedded/lib.sh` (window end next to the `m33f_*` numbers), `cpp/embedded/arm.sh` (`target_m33f`: one stack-top check per image, shared helper), `rust/embedded/target.sh` (`target_rust_m33f`: same helper per image), `README.md` if it names the M33F RAM.

### Proof
Real `cpp-embedded` and `rust-embedded` runs: both rows pass with HEAD figures and the stack top in the log; scratch copies with a 130 KiB array (cpp row fails with the overflow message) and with a 4 MB script (both rows fail naming 0x38020000); `lib.test.sh`, `run-parts.test.sh`, `checks.test.sh` unchanged.

### Risks
Rust row needs the 1.98 toolchain (installed on this host this loop; libs built).
