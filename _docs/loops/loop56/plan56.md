# Autodev Loop Plan — Loop 56

loop: 56
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | done at P0 (3 tasks via feature description) |
| decompose-feature | 9.5 | Decompose Feature | no | done with new-task: AZ-3143, AZ-3144, AZ-3145 |
| implement | 10 | Implement | yes | C++ line (AZ-3143 then AZ-3144) and test-loader line (AZ-3145) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | one total run |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario change |
| update-docs | 13 | Update Docs | yes | C++ description margins, gotchas |
| security | 14 | Security Audit | no | no input, auth or exposure change |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | — |
| migration | 16.7 | Data/Traffic Cutover | no | — |
| retrospective | 17 | Retrospective | no | last retro loop 55, under 5 loops |
| local-deploy | — | Local deploy + open site | yes | at close |
| smoke | — | Smoke acceptance | yes | at close |

## Implementation

### Files that change
cpp/src/core/unpack.cpp, cpp/include/packbin/{table,order}.hpp, cpp/embedded/, cpp/tests/core; go/hostile_loader_test.go, swift/Tests/PackbinTests/{HostileTests,FuzzTests}.swift, one Rust loader.
### Order of work
AZ-3143, then AZ-3144 (C++ worker); AZ-3145 in parallel (test-loader worker).
### Proof
Flash/stack figures from the arm embedded stage; broken-copy runs for the loaders; one total review and one step 11.
### Risks
L55-1 (flash 72 B, stack 8 B).
