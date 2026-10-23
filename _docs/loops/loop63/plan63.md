# Autodev Loop Plan — Loop 63

loop: 63
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done in P0: spec `AZ-PENDING_cpp_pack_flash_saving.md` in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, no feature-description |
| implement | 10 | Implement | yes | find the saving in `pack.cpp`, then `held_of` on top of it |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | host, `gcc:16`, arm stage, `scripts/loop-tests.sh` |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC, scenario or NFR of the project changes |
| update-docs | 13 | Update Docs | yes | flash and stack margins in the C++ description and `AGENT_GOTCHAS.md` when a change is kept |
| security | 14 | Security Audit | no | no auth, secret, network or untrusted-input change; wire output unchanged |
| performance | 15 | Performance Test | no | no latency or throughput AC |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | loops 60 to 62 retro not due: last retro covers loops 56 to 60 and this is the third loop since; check at close |
| local-deploy | — | Local deploy + open site | yes | at close (library: no site; run the loop smoke script) |
| smoke | — | Smoke acceptance | yes | at close |

## Implementation

### Files that change
- `cpp/src/core/pack.cpp` (edit), `cpp/embedded/lib.sh` (pin), `_docs/AGENT_GOTCHAS.md`, `_docs/02_document/components/05_cpp_package/description.md`

### Order of work
1. Baseline on HEAD, then candidates measured on tree copies in the scratchpad (repo at HEAD).
2. Kept shape applied; host, `gcc:16` and arm stage.
3. `held_of` shapes D and A measured on top; owner chose drop.

### Proof
- AC-1 to AC-5, AC-9: `batch_01_loop63_report.md`; AC-6, AC-7: the same table; AC-8 not applicable (held_of dropped).

### Risks
- Error-path stack of the noinline `bad` is not measured by the stage.
