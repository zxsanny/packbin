# Autodev Loop Plan — Loop 126

loop: 126
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | queue item seeded `problem.md`; feature description and ten task specs written straight from it |
| decompose-feature | 9.5 | Decompose Feature | yes (done) | 26 points: AZ-4294 shared, AZ-4295 to AZ-4303 one per package; epic AZ-4133 |
| implement | 10 | Implement | yes | waves of three workers with disjoint package folders (rules: `_docs/02_task_plans/scheme-depth-limit/worker-rules.md`); the parent does AZ-4294 |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total `scripts/loop-tests.sh` run at the end; the probe over all nine packages |
| test-spec-sync | 12 | Test-Spec Sync | no | the contract and the hostile cases carry the new scenarios |
| update-docs | 13 | Update Docs | yes | contract, module layout, README written with AZ-4294; package component docs name the check |
| security | 14 | Security Audit | yes | `lite`: a new input check on schemes, a hostile-input limit (escalates on T1 to T8) |
| performance | 15 | Performance Test | no | no perf NFR (the check is O(size); the probe times it) |
| deploy | 16 | Deploy | no | no ship intent |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | routine loop (retro due by loop 128) |
| local-deploy | — | Local deploy | yes | library: the close runs the probe and the smoke script |
| smoke | — | Smoke acceptance | yes | `smoke126.sh`, agent-verified |

## Waves

W1: AZ-4295 TypeScript, AZ-4297 Python, AZ-4301 Dart. W2: AZ-4296 C#, AZ-4298 Java, AZ-4299 Go. W3: AZ-4300 Swift, AZ-4302 Rust, AZ-4303 C++ (device rows). One wave at a time; the parent commits after each wave.

## Needs

none (toolchains as loop 125 and `_docs/gotchas/mac-host-recipes.md`: python3.13 shim for PyYAML, `RUSTUP_TOOLCHAIN=1.98`, `PACKBIN_CXX_SYSROOT`, Docker for Go and the compose runs).
