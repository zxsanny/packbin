# Autodev Loop Plan — Loop 9

loop: 9
kind: product
confirmed: true
branch: loop/9-pack-session
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` — never a plan row |
| decompose-feature | 9.5 | Decompose Feature | yes | 13 points, handed off |
| implement | 10 | Implement | yes | AZ-2019 through AZ-2026 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | yes | new session ACs |
| update-docs | 13 | Update Docs | yes | public session contract |
| security | 14 | Security Audit | yes | shared seed and untrusted payloads |
| performance | 15 | Performance Test | no | no new latency target |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | deploy excluded |
| migration | 16.7 | Data/Traffic Cutover | no | no schema or traffic cut |
| retrospective | 17 | Retrospective | yes | feature is 13 points |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |

## Implementation

### Files that change
C# public entry first, then the other five packages, then the README.

### Order of work
AZ-2019, then AZ-2020 through AZ-2024, then AZ-2025, and AZ-2026 after AZ-2019.

### Proof
Clear golden hex unchanged. Session payload length 13. Six languages one hex.

### Risks
Shared seed and no per-packet tag are accepted. A dropped packet desynchronizes that session.
