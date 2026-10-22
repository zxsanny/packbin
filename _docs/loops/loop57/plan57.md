# Autodev Loop Plan — Loop 57

loop: 57
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0 (4 tasks via feature description) |
| decompose-feature | 9.5 | Decompose Feature | no | done with new-task: AZ-3151, AZ-3152, AZ-3153, AZ-3154 |
| implement | 10 | Implement | yes | C++ line (AZ-3151, AZ-3152, AZ-3154) and loader line (AZ-3153) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario change to the product |
| update-docs | 13 | Update Docs | yes | C++ description margins, gotchas |
| security | 14 | Security Audit | no | no input, auth or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | yes | loop 56 + 57 = 2 since retro 55? under 5 loops: no |
| local-deploy | — | Local deploy + open site | yes | at close |
| smoke | — | Smoke acceptance | yes | at close |

## Implementation

### Files that change
cpp/src/core/*, cpp/include/packbin/*, cpp/embedded/{lib.sh,arm.sh}; rust/src/hostile_tests.rs, rust/tests/nostd_hostile_tests.rs, swift/Tests/PackbinTests/FuzzTests.swift, go/hostile_loader_test.go, go/hostile_pack_test.go.
### Order of work
AZ-3151, then AZ-3152, then AZ-3154 (C++ worker); AZ-3153 in parallel (loader worker).
### Proof
Flash/stack figures from the arm embedded stage; broken-copy runs for the loaders; one total review and one step 11.
### Risks
L56-1 (flash margin 112 B, stack margin 8 B).
