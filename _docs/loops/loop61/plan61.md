# Autodev Loop Plan — Loop 61

loop: 61
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0: `AZ-PENDING_cpp_pack_held_of_measure` (2 points) |
| decompose-feature | 9.5 | Decompose Feature | no | one task |
| implement | 10 | Implement | yes | the candidate and its measurement (the source may stay at HEAD, AC-3) |
| feature-assess | 10.5 | Feature Assessment | no | no source change when AC-3 drops the candidate; the figures are the proof |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh`: runs the ARM stage if cpp/src changed, skips the rest as unchanged |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario change to the product |
| update-docs | 13 | Update Docs | yes | `AGENT_GOTCHAS.md` line with the figures |
| security | 14 | Security Audit | no | no input, auth or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | last retro loop 60, under 5 loops |
| local-deploy | — | Local deploy + open site | yes | none: a library |
| smoke | — | Smoke acceptance | yes | `smoke61.sh`, agent run (owner rule 2026-10-12) |

## Implementation

### Files that change
`cpp/src/core/pack.cpp` (candidate only, kept when flash is at most 8,032 B), `_docs/AGENT_GOTCHAS.md`.
### Order of work
Baseline, candidate shapes A to E measured with the M4F target of `cpp/embedded/arm.sh`; decision by AC-3.
### Proof
`smoke61.sh` reproduces the baseline and the rejected candidate in scratch copies.
### Risks
L57-1 (flash margin 160 B, stack margin 8 B).
