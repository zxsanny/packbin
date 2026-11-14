# Autodev Loop Plan — Loop 125

loop: 125
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | spec written straight from the queue item (3 points, probe only) |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points, one task |
| implement | 10 | Implement | yes | AZ-4291: probes under `scripts/probes/scheme-depth/`, findings under `_docs/06_metrics/`; four workers with disjoint package folders |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` (only `scaffold` sees `scripts/`) |
| test-spec-sync | 12 | Test-Spec Sync | no | no product AC changed |
| update-docs | 13 | Update Docs | no | no public contract changed |
| security | 14 | Security Audit | no | trivial: probes and documents only (loop 112/116 precedent) |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | no ship intent |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | routine loop (retro due by loop 128) |
| local-deploy | — | Local deploy | yes | library: the close runs the probe and the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke125.sh`, agent-verified |

## Needs

none (toolchains as the loop 116 probes: Go in `golang:1.27`, `RUSTUP_TOOLCHAIN=1.98`, `PACKBIN_CXX_SYSROOT`, Python 3.13, .NET 10, Dart in its container or on PATH — see `_docs/AGENT_GOTCHAS.md`).
