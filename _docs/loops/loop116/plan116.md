# Autodev Loop Plan — Loop 116

loop: 116
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | queue item seeded `problem.md`; spec written straight from it (3 points, probe only) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-4242: probes under `scripts/probes/element-row/`, findings under `_docs/06_metrics/`; one worker per package (disjoint folders) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` (only `scaffold` sees `scripts/`; package suites unchanged) |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC or scenario changed |
| update-docs | 13 | Update Docs | no | no public contract changed |
| security | 14 | Security Audit | no | trivial: probes and documents only, no package source, CI, compose, deploy file or dependency (loop 112 precedent) |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | no ship intent |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | routine loop (retro due by loop 118) |
| local-deploy | — | Local deploy + open site | yes | library: the close runs the probe and the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke116.sh`, agent-verified |

## Needs

none (toolchains of the loop 112 probes; Go in `golang:1.27`; `RUSTUP_TOOLCHAIN=1.98`, `PACKBIN_CXX_SYSROOT`, Python 3.13 per `_docs/AGENT_GOTCHAS.md`).
