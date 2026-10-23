# Autodev Loop Plan — Loop 65

loop: 65
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | spec written from `problem.md` / ACs at P0 (`_docs/02_tasks/todo/AZ-PENDING_ci_paths_ignore_rust_limits_flag_round_chain.md`), 3 points |
| decompose-feature | 9.5 | Decompose Feature | no | 3 points |
| implement | 10 | Implement | yes | three small parts, no overlap of files |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` once, plus the arm embedded stage |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC of the product changed |
| update-docs | 13 | Update Docs | yes | limits and the new figure in the Rust and C++ component descriptions, `AGENT_GOTCHAS.md` |
| security | 14 | Security Audit | no | no input, auth or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | last retro loops 61-63; next after loop 68 |
| local-deploy | — | Local deploy + open site | yes | none: a library |
| smoke | — | Smoke acceptance | yes | `smoke65.sh`, agent run (owner rule 2026-10-12) |

## Implementation

### Files that change
`.github/workflows/test.yml`; `rust/embedded/{limits.txt,checks.test.sh,README.md}`; `cpp/embedded/common/all_kinds.{hpp,cpp}`, `cpp/embedded/arm/ac2_main.cpp`, `cpp/embedded/common/vectors_main.cpp`, `cpp/tests/core/when_chain_host_tests.cpp`; documents.
### Order of work
1. Limits (figures already measured on HEAD). 2. Workflow edit and check. 3. C++ case: host test first, then the arm stage (about 3 minutes). 4. Docs, step 11, smoke, close.
### Proof
`smoke65.sh`: the workflow check, `checks.test.sh`, the one-byte-under stage run, the arm stage rows.
### Risks
The new case may exceed 512 B of stack (stop and report). `rust/embedded/limits.txt` pins at +5%: a later legitimate edit needs a raise with a line saying what the bytes bought.
