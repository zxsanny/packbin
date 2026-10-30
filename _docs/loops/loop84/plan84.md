# Autodev Loop Plan - Loop 84

loop: 84
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done: AZ-3390 to AZ-3393 in `todo/` |
| decompose-feature | 9.5 | Decompose Feature | no | four tasks of 2-3 points |
| implement | 10 | Implement | yes | one batch, three workers on disjoint paths (W1 AZ-3390 then AZ-3393, W2 AZ-3391, W3 AZ-3392) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC or scenario of the blackbox spec changed |
| update-docs | 13 | Update Docs | no | no public contract or module doc changed |
| security | 14 | Security Audit | no | no auth, secret or untrusted input; 11-point non-ship loop |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | no data store |
| retrospective | 17 | Retrospective | yes | last retro loop 79; loop 84 is the 5th since (record83: "next after loop 84") |
| local-deploy | - | Local deploy + open site | yes | always at close; no app: the stages the touched scripts belong to |
| smoke | - | Smoke acceptance | yes | always at close |

## Implementation

Write sets (exclusive):
- W1: `.github/workflows/ring-wiring-check.py`, `ring-wiring.test.sh`, `test.yml` (AZ-3390 first, then AZ-3393).
- W2: `cpp/Makefile`, `cpp/embedded/**` (AZ-3391).
- W3: `.github/workflows/drivers/handoff_ecc.cpp`, `handoff_frame.cpp` (and `handoff.cpp` only for a 0-use include), `ring-frame.test.sh`, `scripts/frame/ring_frame.py` (AZ-3392).
Each worker runs in its own copy of the tree (`git archive HEAD`); the parent diffs each copy against HEAD for the owned paths before copying back. No worker touches git, Jira or docker compose.

### Divergence (batch 1)

- AZ-3391: the second translation unit costs 40 B on the Cortex-M33F image; owner (2026-10-30) chose to raise `m33f_flash_pin` 25720 -> 25760 (`cpp/embedded/lib.sh`, `AGENT_GOTCHAS.md`). Also edited by the parent: `ring-frame.sh` header, `ci_cd_pipeline.md` lines 21 and 37.
- AZ-3392: no include was removable (all used); the other work stands.
