# Autodev Loop Plan — Loop 75

loop: 75
kind: product
confirmed: true
branch: dev
ship: false

Tasks: AZ-3292 (C++), AZ-3293 (Go), AZ-3294 (Python), AZ-3295 (TypeScript), 5 points each, claimed at intake 88cbb2b. Specs decided by the owner on 2026-10-26 (D4); no new-task.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs exist in todo/ |
| decompose-feature | 9.5 | Decompose Feature | no | four atomic specs |
| implement | 10 | Implement | yes | four disjoint packages, one wave of four workers |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run (owner preference) |
| test-spec-sync | 12 | Test-Spec Sync | no | ACs equal the spec; blackbox rows added in docs step |
| update-docs | 13 | Update Docs | yes | README frame examples, component descriptions, module-layout, contract consumers |
| security | 14 | Security Audit | yes | crypto and authentication code in four packages |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | |
| migration | 16.7 | Data/Traffic Cutover | no | |
| retrospective | 17 | Retrospective | no | last loop 74; next due after loop 79 |
| local-deploy | — | Local deploy + open site | yes | library repo: no site; scripts/loop-tests.sh and a smoke script |
| smoke | — | Smoke acceptance | yes | mandatory |

## Implementation

### Files that change
- `cpp/` (include, src/core, tests, embedded rows), `go/`, `python/`, `typescript/`: one worker each, disjoint.
- Parent only: `README.md` frame sections, `scripts/frame/readme-examples.sh`, component docs, `module-layout.md`, contract consumer list, `ring`/CI lists.

### Order of work
1. Four workers in parallel (reference: `csharp/Frame*.cs`, `MacKey.cs`, `ReplayWindow.cs`; Rust `rust/src/nostd/frame`).
2. Parent applies README/docs hunks, runs focused checks, commits one batch.
3. Feature-assess, one total step 11, security review, docs, smoke.

### Proof
- 157 of 157 `fixtures/frame/vectors.txt` rows and 27 of 27 crypto rows per package.

### Risks
- C++ M4F/M33F/AVR pins (frame image measured on HEAD); Python/TypeScript load factor; Go intermittent test (L74-3).
